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

    private let timeoutDuration: TimeInterval
    private let airScanDelay: TimeInterval
    private let firmwareRevision: ((String, @escaping (Result<String, Error>) -> Void) -> Void)?
    private let airScan: ((@escaping (RuuviTagSensorRecord) -> Void) -> (() -> Void))?

    init(
        deviceType: RuuviDeviceType = .ruuviTag,
        firmwareType: RuuviDFUFirmwareType,
        session: URLSession = .shared,
        firmwareRepository: FirmwareRepository = FirmwareRepositoryImpl(),
        timeoutDuration: TimeInterval = 15,
        airScanDelay: TimeInterval = 5,
        firmwareRevision: ((String, @escaping (Result<String, Error>) -> Void) -> Void)? = nil,
        airScan: ((@escaping (RuuviTagSensorRecord) -> Void) -> (() -> Void))? = nil
    ) {
        self.deviceType = deviceType
        self.firmwareType = firmwareType
        self.session = session
        self.timeoutDuration = timeoutDuration
        self.airScanDelay = airScanDelay
        self.firmwareRevision = firmwareRevision
        self.airScan = airScan
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

    func serveCurrentRelease(for ruuviTag: RuuviTagSensor) -> AnyPublisher<CurrentRelease, Error> {
        guard let uuid = ruuviTag.luid?.value else {
            return Fail(error: DFUError.failedToGetLuid).eraseToAnyPublisher()
        }
        return firmwareObservation(timeout: (timeoutDuration, BTError.logic(.connectionTimedOut) as Error)) { [self] complete in
            let receive: (Result<String, Error>) -> Void = { complete($0.map { CurrentRelease(version: $0) }) }
            if let firmwareRevision {
                firmwareRevision(uuid, receive)
            } else {
                background.services.gatt.firmwareRevision(for: self, uuid: uuid,
                    options: [.connectionTimeout(timeoutDuration), .serviceTimeout(timeoutDuration)]) { _, result in
                    receive(result.mapError { $0 as Error })
                }
            }
            return nil
        }
        .handleEvents(receiveOutput: { [weak self] release in
            self?.syncStoredFirmwareVersionIfNeeded(release.version, for: ruuviTag)
        })
        .eraseToAnyPublisher()
    }

    func listen(ruuviTag: RuuviTagSensor) -> AnyPublisher<DFUDevice, Never> {
        let format = RuuviDataFormat.dataFormat(from: ruuviTag.version)
        let skipScanServices = format == .e1 || format == .v6
        return firmwareObservation { [self] complete in
            let token = ruuviDFU.scan(self, includeScanServices: !skipScanServices) { _, device in
                if !skipScanServices || device.uuid == ruuviTag.luid?.value { complete(.success(device)) }
            }
            return { token.invalidate() }
        }
    }

    func waitForAirDevice(ruuviTag: RuuviTagSensor, timeout: TimeInterval) -> AnyPublisher<Void, Error> {
        guard deviceType == .ruuviAir else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        return firmwareObservation(delay: airScanDelay, timeout: (timeout, DFUError.airDeviceTimeout as Error)) { [self] complete in
            let receive: (RuuviTagSensorRecord) -> Void = { [self] advertisement in
                if isSameDevice(advertisement, ruuviTag) { complete(.success(())) }
            }
            if let airScan { return airScan(receive) }
            guard let foreground else { complete(.success(())); return nil }
            let token = foreground.scan(self) { _, device in
                if let advertisement = device.ruuvi?.tag { receive(advertisement) }
            }
            return { token.invalidate() }
        }
    }

    func observeLost(uuid: String) -> AnyPublisher<String, Never> {
        firmwareObservation { [self] complete in
            let token = ruuviDFU.lost(self) { _, device in
                if device.uuid == uuid { complete(.success(uuid)) }
            }
            return { token.invalidate() }
        }
    }
}

extension DFUInteractor {
    private func isSameDevice(_ lhs: RuuviTagSensorRecord, _ rhs: RuuviTagSensor) -> Bool {
        if let lhsMac = lhs.macId?.any, let rhsMac = rhs.macId?.any, lhsMac == rhsMac {
            return true
        }
        if let lhsLuid = lhs.luid?.any, let rhsLuid = rhs.luid?.any, lhsLuid == rhsLuid {
            return true
        }
        return false
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
