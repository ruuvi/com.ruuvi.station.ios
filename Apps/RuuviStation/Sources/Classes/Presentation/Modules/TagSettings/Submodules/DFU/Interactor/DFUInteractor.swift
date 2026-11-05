// swiftlint:disable file_length
import BTKit
import Combine
import Foundation
import RuuviDFU
import RuuviFirmware
import RuuviOntology
import RuuviLocal
import RuuviPool
import RuuviStorage

final class DFUInteractor {
    var ruuviDFU: RuuviDFU!
    var background: BTBackground!
    var foreground: BTForeground!
    var ruuviPool: RuuviPool!
    var ruuviStorage: RuuviStorage!
    private let deviceType: RuuviDeviceType
    private let firmwareType: RuuviDFUFirmwareType

    private let session: URLSession
    private let downloader: FirmwareDownloader

    private var timer: Timer?
    private var timeoutDuration: Double = 15
    private var ruuviTags = Set<AnyRuuviTagSensor>()
    private var airScanToken: ObservationToken?
    private var airScanTimeoutTimer: Timer?

    init(
        deviceType: RuuviDeviceType = .ruuviTag,
        firmwareType: RuuviDFUFirmwareType,
        session: URLSession = .shared,
        firmwareRepository: FirmwareRepository = FirmwareRepositoryImpl()
    ) {
        self.deviceType = deviceType
        self.firmwareType = firmwareType
        self.session = session
        downloader = FirmwareDownloader(session: session, repository: firmwareRepository)
    }
}

extension DFUInteractor: DFUInteractorInput {

    // swiftlint:disable:next function_parameter_count
    func flash(
        dfuDevice: DFUDevice,
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?,
        appUrl: URL,
        fullUrl: URL,
        additionalFiles: [URL]
    ) -> AnyPublisher<FlashResponse, Error> {
        switch deviceType {
        case .ruuviTag:
            let firmwareUrl: URL
            if let currentMajor = currentRelease?.version.semVar?.first,
                let latestMajor = latestRelease.version.semVar?.first,
                currentMajor == latestMajor
            {
                firmwareUrl = appUrl
            } else {
                firmwareUrl = fullUrl
            }
            guard
                let firmware = ruuviDFU.firmwareFromUrl(
                    url: firmwareUrl
                )
            else {
                return Fail<
                    FlashResponse,
                    Error
                >(
                    error: DFUError.failedToConstructFirmwareFromFile
                )
                .eraseToAnyPublisher()
            }
            return
                ruuviDFU
                .flashFirmware(
                    uuid: dfuDevice.uuid,
                    with: firmware
                )
                .eraseToAnyPublisher()

        case .ruuviAir:
            var firmwareUrls: [URL] = [appUrl]
            for url in additionalFiles where !firmwareUrls.contains(url) {
                firmwareUrls.append(url)
            }
            return ruuviDFU.flashFirmware(dfuDevice: dfuDevice, with: firmwareUrls)
        }
    }

    func download(
        release: LatestRelease,
        currentRelease: CurrentRelease?
    ) -> AnyPublisher<FirmwareDownloadResponse, Error> {
        let assets: [FirmwareDownloadAsset]
        switch deviceType {
        case .ruuviTag:
            guard let fullName = release.defaultFullZipName,
                let fullURL = release.defaultFullZipUrl,
                let appName = release.defaultAppZipName,
                let appURL = release.defaultAppZipUrl
            else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            assets = [.init(name: appName, url: appURL), .init(name: fullName, url: fullURL)]
        case .ruuviAir:
            let selected = currentRelease?.isDevBuild == true ? release.assets : Array(release.assets.prefix(1))
            assets = selected.compactMap { asset in
                URL(string: asset.downloadUrlString).map { .init(name: asset.name, url: $0) }
            }
            guard assets.count == selected.count else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
        }
        let isAir = deviceType == .ruuviAir
        return downloader.download(assets: assets)
            .map { event in
                switch event {
                case .progress(let progress): return .progress(progress)
                case .files(let files):
                    return .response(
                        appUrl: files[0], fullUrl: isAir ? files[0] : files[1],
                        additionalFiles: isAir ? Array(files.dropFirst()) : [])
                }
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error> {
        switch deviceType {
        case .ruuviTag:
            let urlString = firmwareDownloadURL(for: .ruuviTag)
            guard let url = URL(string: urlString) else {
                return Fail<LatestRelease, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            return session.firmwareDataPublisher(for: url)
                .decode(type: LatestRelease.self, decoder: JSONDecoder())
                .catch { error in Fail<LatestRelease, Error>(error: error) }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()

        case .ruuviAir:
            let urlString = firmwareDownloadURL(for: .ruuviAir)
            guard let url = URL(string: urlString) else {
                return Fail<LatestRelease, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            return session.firmwareDataPublisher(for: url)
                .decode(type: RuuviAirFirmwareResponse.self, decoder: JSONDecoder())
                .tryMap { [firmwareType] response in
                    guard response.result == "success",
                        let release = response.data.toLatestRelease(firmwareType: firmwareType)
                    else {
                        throw URLError(.badServerResponse)
                    }
                    return release
                }
                .catch { error in Fail<LatestRelease, Error>(error: error) }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }
    }

    func serveCurrentRelease(for ruuviTag: RuuviTagSensor) -> Future<CurrentRelease, Error> {
        Future { [weak self] promise in
            guard let sSelf = self else { return }
            guard let uuid = ruuviTag.luid?.value
            else {
                promise(.failure(DFUError.failedToGetLuid))
                return
            }

            sSelf.invalidateTimer()
            sSelf.timer = Timer.scheduledTimer(
                withTimeInterval: sSelf.timeoutDuration, repeats: false
            ) { _ in
                sSelf.invalidateTimer()
                promise(.failure(BTError.logic(.connectionTimedOut)))
            }

            sSelf.background.services.gatt.firmwareRevision(
                for: sSelf,
                uuid: uuid,
                options: [
                    .connectionTimeout(sSelf.timeoutDuration),
                    .serviceTimeout(sSelf.timeoutDuration),
                ]
            ) { _, result in
                sSelf.invalidateTimer()
                switch result {
                case let .success(version):
                    sSelf.syncStoredFirmwareVersionIfNeeded(version, for: ruuviTag)
                    let currentRelease = CurrentRelease(version: version)
                    promise(.success(currentRelease))
                case let .failure(error):
                    promise(.failure(error))
                }
            }
        }
    }

    func listen(ruuviTag: RuuviTagSensor) -> Future<DFUDevice, Never> {
        let firmwareType = RuuviDataFormat.dataFormat(
            from: ruuviTag.version
        )
        let skipScanServices = firmwareType == .e1 || firmwareType == .v6

        return Future { [weak self] promise in
            guard let sSelf = self else { return }
            sSelf.ruuviDFU.scan(
                sSelf,
                includeScanServices: !skipScanServices
            ) {
                _,
                device in
                if skipScanServices {
                    if device.uuid == ruuviTag.luid?.value {
                        promise(.success(device))
                    }
                } else {
                    // For older devices we return the device found in Bootloader mode.
                    promise(.success(device))
                }
            }
        }
    }

    func waitForAirDevice(
        ruuviTag: RuuviTagSensor,
        timeout: TimeInterval
    ) -> AnyPublisher<Void, Error> {
        guard deviceType == .ruuviAir else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return Future { [weak self] promise in
            guard let self else { return }

            var hasCompleted = false

            func complete(_ result: Result<Void, Error>) {
                guard !hasCompleted else { return }
                hasCompleted = true
                self.stopAirScan()
                switch result {
                case .success:
                    promise(.success(()))
                case let .failure(error):
                    promise(.failure(error))
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self else { return }

                guard let foreground else {
                    complete(.success(()))
                    return
                }

                self.stopAirScan()
                self.ruuviTags.removeAll()

                self.airScanToken = foreground.scan(self) { observer, device in
                    guard let advertisement = device.ruuvi?.tag else {
                        return
                    }
                    observer.handleAirAdvertisement(
                        advertisement: advertisement,
                        target: ruuviTag
                    ) {
                        complete(.success(()))
                    }
                }

                self.airScanTimeoutTimer = Timer.scheduledTimer(
                    withTimeInterval: timeout,
                    repeats: false
                ) { _ in
                    complete(.failure(DFUError.airDeviceTimeout))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func observeLost(uuid: String) -> Future<String, Never> {
        Future { [weak self] promise in
            guard let sSelf = self else { return }
            sSelf.ruuviDFU.lost(
                sSelf,
                closure: { _, device in
                    if device.uuid == uuid {
                        promise(.success(uuid))
                    }
                })
        }
    }
}

extension DFUInteractor {
    private func handleAirAdvertisement(
        advertisement: RuuviTagSensorRecord,
        target: RuuviTagSensor,
        onMatch: @escaping () -> Void
    ) {
        ruuviTags.update(with: target.any)

        if isSameDevice(advertisement, target) {
            onMatch()
        }
    }

    private func stopAirScan() {
        let invalidate: (DFUInteractor) -> Void = { interactor in
            interactor.airScanToken?.invalidate()
            interactor.airScanToken = nil
            interactor.airScanTimeoutTimer?.invalidate()
            interactor.airScanTimeoutTimer = nil
            interactor.ruuviTags.removeAll()
        }

        if Thread.isMainThread {
            invalidate(self)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                invalidate(self)
            }
        }
    }

    private func isSameDevice(_ lhs: RuuviTagSensorRecord, _ rhs: RuuviTagSensor) -> Bool {
        if let lhsMac = lhs.macId?.any, let rhsMac = rhs.macId?.any, lhsMac == rhsMac {
            return true
        }
        if let lhsLuid = lhs.luid?.any, let rhsLuid = rhs.luid?.any, lhsLuid == rhsLuid {
            return true
        }
        return false
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func syncStoredFirmwareVersionIfNeeded(
        _ version: String,
        for ruuviTag: RuuviTagSensor
    ) {
        resolveLatestSensor(for: ruuviTag) { [weak self] latestTag in
            guard let self else { return }
            guard let ruuviPool = self.ruuviPool else { return }
            let storedVersion = latestTag.firmwareVersion
            let latestVersion = version

            guard
                !self.areStoredFirmwareDisplayValuesEquivalent(
                    storedVersion,
                    latestVersion
                )
            else { return }

            Task { @MainActor [self] in _ = try? await ruuviPool.update(latestTag.with(firmwareVersion: version)) }
        }
    }

    private func areStoredFirmwareDisplayValuesEquivalent(
        _ lhs: String?,
        _ rhs: String
    ) -> Bool {
        let normalizedLhs = lhs?.canonicalFirmwareDisplayIdentifier
        let normalizedRhs = rhs.canonicalFirmwareDisplayIdentifier

        return normalizedLhs == normalizedRhs
    }

    private func resolveLatestSensor(
        for ruuviTag: RuuviTagSensor,
        completion: @escaping (RuuviTagSensor) -> Void
    ) {
        guard let ruuviStorage = ruuviStorage else {
            completion(ruuviTag)
            return
        }

        let sensorId = ruuviTag.macId?.value ?? ruuviTag.id
        Task { @MainActor [self] in
            do throws(RuuviStorageError) {
                let value = try await ruuviStorage.readOne(sensorId)
                ({ completion($0) })(value)
            } catch {
                ({ _ in completion(ruuviTag) })(error)
            }
        }
    }

    private func firmwareDownloadURL(for deviceType: RuuviDeviceType) -> String {
        switch deviceType {
        case .ruuviTag:
            return "https://api.github.com/repos/ruuvi/ruuvi.firmware.c/releases/latest"
        case .ruuviAir:
            let appGroupDefaults = UserDefaults(
                suiteName: AppGroupConstants.appGroupSuiteIdentifier
            )
            let useDevServer =
                appGroupDefaults?.bool(
                    forKey: AppGroupConstants.useDevServerKey
                ) ?? false
            let baseUrlString: String =
                useDevServer ? AppAssemblyConstants.ruuviCloudUrlDev : AppAssemblyConstants.ruuviCloudUrl
            return "\(baseUrlString)/air_firmwareupdate"
        }
    }
}
