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
    private let deviceType: RuuviDeviceType
    private let firmwareType: RuuviDFUFirmwareType

    private let firmwareRepository: FirmwareRepository = FirmwareRepositoryImpl()

    private var timer: Timer?
    private var timeoutDuration: Double = 15

    init(
        deviceType: RuuviDeviceType = .ruuviTag,
        firmwareType: RuuviDFUFirmwareType
    ) {
        self.deviceType = deviceType
        self.firmwareType = firmwareType
    }
}

extension DFUInteractor: DFUInteractorInput {
    func flash(
        dfuDevice: DFUDevice,
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?,
        appUrl: URL,
        fullUrl: URL
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
            return ruuviDFU.flashFirmware(dfuDevice: dfuDevice, with: appUrl)
        }
    }

    func download(release: LatestRelease) -> AnyPublisher<FirmwareDownloadResponse, Error> {
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
            return app.combineLatest(full).map { app, full in
                switch (app, full) {
                case let (.progress(appProgress), .progress): .progress(appProgress)
                case let (.progress(appProgress), .response): .progress(appProgress)
                case let (.response, .progress(fullProgress)): .progress(fullProgress)
                case let (.response(appUrl), .response(fullUrl)): .response(appUrl: appUrl, fullUrl: fullUrl)
                }
            }.eraseToAnyPublisher()

        case .ruuviAir:
            guard let asset = release.assets.first,
                  let url = URL(string: asset.downloadUrlString) else {
                return Fail<FirmwareDownloadResponse, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let progress = Progress(totalUnitCount: 1)
            return download(url: url, name: asset.name, progress: progress)
                .map { response in
                    switch response {
                    case let .progress(progress): return .progress(progress)
                    case let .response(fileUrl): return .response(appUrl: fileUrl, fullUrl: fileUrl)
                    }
                }.eraseToAnyPublisher()
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
        let firmwareType = RuuviFirmwareVersion.firmwareVersion(
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
