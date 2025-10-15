// swiftlint:disable file_length
import BTKit
import Combine
import Foundation
import RuuviDFU
import RuuviFirmware
import RuuviOntology
import RuuviLocal

final class DFUInteractor {
    var ruuviDFU: RuuviDFU!
    var background: BTBackground!
    var foreground: BTForeground!
    private let deviceType: RuuviDeviceType
    private let firmwareType: RuuviDFUFirmwareType

    private let firmwareRepository: FirmwareRepository = FirmwareRepositoryImpl()

    private var timer: Timer?
    private var timeoutDuration: Double = 15
    private var downloadCancellables = Set<AnyCancellable>()
    private var ruuviTags = Set<AnyRuuviTagSensor>()
    private var airScanToken: ObservationToken?
    private var airScanTimeoutTimer: Timer?

    init(
        deviceType: RuuviDeviceType = .ruuviTag,
        firmwareType: RuuviDFUFirmwareType
    ) {
        self.deviceType = deviceType
        self.firmwareType = firmwareType
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
            if let currentRelease {
                let currentMajor = currentRelease.version.drop(
                    while: {
                        !$0.isNumber
                    }).prefix(
                        while: {
                            $0 != "."
                        })
                let latestMajor = latestRelease.version.drop(
                    while: {
                        !$0.isNumber
                    }).prefix(
                        while: {
                            $0 != "."
                        })
                if currentMajor == latestMajor {
                    firmwareUrl = appUrl
                } else {
                    firmwareUrl = fullUrl
                }
            } else {
                firmwareUrl = fullUrl
            }
            guard let firmware = ruuviDFU.firmwareFromUrl(
                url: firmwareUrl
            ) else {
                return Fail<
                    FlashResponse,
                    Error
                >(
                    error: DFUError.failedToConstructFirmwareFromFile
                )
                .eraseToAnyPublisher()
            }
            return ruuviDFU
                .flashFirmware(
                    uuid: dfuDevice.uuid,
                    with: firmware
                )
                .eraseToAnyPublisher()

        case .ruuviAir:
            var firmwareUrls: [URL] = [appUrl]
            for url in additionalFiles where url != appUrl {
                firmwareUrls.append(url)
            }
            return ruuviDFU.flashFirmware(dfuDevice: dfuDevice, with: firmwareUrls)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func download(
        release: LatestRelease,
        currentRelease: CurrentRelease?
    ) -> AnyPublisher<FirmwareDownloadResponse, Error> {
        switch deviceType {
        case .ruuviTag:
            guard let fullName = release.defaultFullZipName,
                  let fullUrl = release.defaultFullZipUrl,
                  let appName = release.defaultAppZipName,
                  let appUrl = release.defaultAppZipUrl else {
                return Fail<FirmwareDownloadResponse, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let progress = Progress(totalUnitCount: 2)
            let full = download(url: fullUrl, name: fullName, progress: progress)
            let app = download(url: appUrl, name: appName, progress: progress)
            return app.combineLatest(full).map {
                app,
                full in
                switch (app, full) {
                case let (
                    .progress(
                        appProgress
                    ),
                    .progress
                ): .progress(
                    appProgress
                )
                case let (
                    .progress(
                        appProgress
                    ),
                    .response
                ): .progress(
                    appProgress
                )
                case let (
                    .response,
                    .progress(
                        fullProgress
                    )
                ): .progress(
                    fullProgress
                )
                case let (
                    .response(
                        appUrl
                    ),
                    .response(
                        fullUrl
                    )
                ): .response(
                    appUrl: appUrl,
                    fullUrl: fullUrl,
                    additionalFiles: []
                )
                }
            }.eraseToAnyPublisher()

        case .ruuviAir:
            guard let primaryAsset = release.assets.first else {
                return Fail<FirmwareDownloadResponse, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }

            let needsAdditionalFiles = currentRelease?.isDevBuild ?? false
            let assetsToDownload: [LatestReleaseAsset]
            if needsAdditionalFiles {
                let additionalAssets = release.assets.dropFirst()
                assetsToDownload = [primaryAsset] + additionalAssets
            } else {
                assetsToDownload = [primaryAsset]
            }

            let assetEntries: [(asset: LatestReleaseAsset, url: URL)] = assetsToDownload.compactMap { asset in
                guard let url = URL(string: asset.downloadUrlString) else {
                    return nil
                }
                return (asset, url)
            }

            guard assetEntries.count == assetsToDownload.count, !assetEntries.isEmpty else {
                return Fail<FirmwareDownloadResponse, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }

            let progress = Progress(totalUnitCount: Int64(assetEntries.count))
            let subject = PassthroughSubject<FirmwareDownloadResponse, Error>()

            var downloadedFiles = [URL?](repeating: nil, count: assetEntries.count)
            var hasCompleted = false

            downloadCancellables.forEach { $0.cancel() }
            downloadCancellables.removeAll()

            for (index, entry) in assetEntries.enumerated() {
                let cancellable = download(
                    url: entry.url,
                    name: entry.asset.name,
                    progress: progress
                )
                .sink(
                    receiveCompletion: { [weak self] completion in
                        guard let self else { return }
                        switch completion {
                        case let .failure(error):
                            if !hasCompleted {
                                hasCompleted = true
                                subject.send(completion: .failure(error))
                                self.downloadCancellables.forEach { $0.cancel() }
                                self.downloadCancellables.removeAll()
                            }
                        case .finished:
                            break
                        }
                    },
                    receiveValue: { [weak self] response in
                        guard let self else { return }
                        switch response {
                        case let .progress(progressValue):
                            subject.send(.progress(progressValue))
                        case let .response(fileUrl):
                            downloadedFiles[index] = fileUrl
                            if downloadedFiles.allSatisfy({ $0 != nil }), !hasCompleted {
                                hasCompleted = true
                                let urls = downloadedFiles.compactMap { $0 }
                                guard let primaryFileUrl = urls.first else {
                                    subject.send(completion: .failure(URLError(.cannotCreateFile)))
                                    self.downloadCancellables.forEach { $0.cancel() }
                                    self.downloadCancellables.removeAll()
                                    return
                                }
                                let additional = Array(urls.dropFirst())
                                subject.send(
                                    .response(
                                        appUrl: primaryFileUrl,
                                        fullUrl: primaryFileUrl,
                                        additionalFiles: additional
                                    )
                                )
                                subject.send(completion: .finished)
                                self.downloadCancellables.forEach { $0.cancel() }
                                self.downloadCancellables.removeAll()
                            }
                        }
                    }
                )

                downloadCancellables.insert(cancellable)
            }

            return subject.eraseToAnyPublisher()
        }
    }

    func download(url: URL, name: String, progress: Progress) -> AnyPublisher<DownloadResponse, Error> {
        URLSession.shared
            .downloadTaskPublisher(for: url, progress: progress)
            .catch { error in Fail<DownloadResponse, Error>(error: error) }
            .map { [weak self] response in
                guard let sSelf = self else { return response }
                switch response {
                case let .response(fileUrl):
                    if let movedUrl = try? sSelf.firmwareRepository.save(
                        name: name,
                        fileUrl: fileUrl
                    ) {
                        return .response(fileUrl: movedUrl)
                    } else {
                        return response
                    }
                case .progress:
                    return response
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
            return URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: LatestRelease.self, decoder: JSONDecoder())
                .catch { error in Fail<LatestRelease, Error>(error: error) }
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()

        case .ruuviAir:
            let urlString = firmwareDownloadURL(for: .ruuviAir)
            guard let url = URL(string: urlString) else {
                return Fail<LatestRelease, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            return URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: RuuviAirFirmwareResponse.self, decoder: JSONDecoder())
                .compactMap { response in
                    return response.data
                        .toLatestRelease(firmwareType: self.firmwareType)
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
                switch result {
                case let .success(version):
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
            ) { _,
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
            sSelf.ruuviDFU.lost(sSelf, closure: { _, device in
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

    private func firmwareDownloadURL(for deviceType: RuuviDeviceType) -> String {
        switch deviceType {
        case .ruuviTag:
            return "https://api.github.com/repos/ruuvi/ruuvi.firmware.c/releases/latest"
        case .ruuviAir:
            let appGroupDefaults = UserDefaults(
                suiteName: AppGroupConstants.appGroupSuiteIdentifier
            )
            let useDevServer = appGroupDefaults?.bool(
                forKey: AppGroupConstants.useDevServerKey
            ) ?? false
            let baseUrlString: String = useDevServer ?
                AppAssemblyConstants.ruuviCloudUrlDev : AppAssemblyConstants.ruuviCloudUrl
            return "\(baseUrlString)/air_firmwareupdate"
        }
    }
}
