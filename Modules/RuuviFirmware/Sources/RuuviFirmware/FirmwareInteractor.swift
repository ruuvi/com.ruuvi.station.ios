import BTKit
import Combine
import Foundation
import RuuviDaemon
import RuuviDFU
import RuuviOntology

struct CurrentRelease {
    var version: String
}

enum FirmwareDownloadResponse {
    case progress(Progress)
    case response(appUrl: URL, fullUrl: URL)
}

enum FirmwareError: Error {
    case failedToGetFirmwareName
    case failedToConstructFirmwareFromFile
}

protocol FirmwareInteracting {
    var batteryIsLow: CurrentValueSubject<Bool, Never> { get }
    func restartPropertiesDaemon()
    func ensureBatteryHasEnoughPower(uuid: String)
    func loadLatestGitHubRelease() -> AnyPublisher<GitHubRelease, Error>
    func serveCurrentRelease(uuid: String) -> Future<CurrentRelease, Error>
    func download(release: GitHubRelease) -> AnyPublisher<FirmwareDownloadResponse, Error>
    func listen() -> Future<String, Never>
    func observeLost(uuid: String) -> Future<String, Never>
    func flash(
        uuid: String, latestRelease: GitHubRelease, currentRelease: CurrentRelease?,
        appUrl: URL, fullUrl: URL
    ) -> AnyPublisher<FlashResponse, Error>
}

final class FirmwareInteractor: FirmwareInteracting {
    var batteryIsLow = CurrentValueSubject<Bool, Never>(false)
    private let background: BTBackground
    private let foreground: BTForeground
    private let propertiesDaemon: RuuviTagPropertiesDaemon
    private let session: URLSession
    private let downloader: FirmwareDownloader
    private let ruuviDFU: RuuviDFU
    private var ruuviTagObservationToken: ObservationToken?

    init(
        background: BTBackground,
        foreground: BTForeground,
        propertiesDaemon: RuuviTagPropertiesDaemon,
        ruuviDFU: RuuviDFU,
        firmwareRepository: FirmwareRepository,
        session: URLSession = .shared
    ) {
        self.background = background
        self.foreground = foreground
        self.propertiesDaemon = propertiesDaemon
        self.ruuviDFU = ruuviDFU
        self.session = session
        downloader = FirmwareDownloader(session: session, repository: firmwareRepository)
    }

    deinit {
        ruuviTagObservationToken?.invalidate()
    }

    func restartPropertiesDaemon() {
        propertiesDaemon.start()
    }

    func ensureBatteryHasEnoughPower(uuid: String) {
        ruuviTagObservationToken?.invalidate()
        ruuviTagObservationToken = foreground.observe(self, uuid: uuid) { observer, device in
            if let ruuviTag = device.ruuvi?.tag {
                observer.batteryIsLow.value = observer.batteryNeedsReplacement(ruuviTag: ruuviTag)
            }
        }
    }

    private func batteryNeedsReplacement(
        ruuviTag: RuuviTag
    ) -> Bool {
        if let temperature = ruuviTag.celsius,
            let voltage = ruuviTag.volts
        {
            if temperature < 0, temperature >= -20 {
                voltage < 2.3
            } else if temperature < -20 {
                voltage < 2
            } else {
                voltage < 2.5
            }
        } else {
            false
        }
    }

    func loadLatestGitHubRelease() -> AnyPublisher<GitHubRelease, Error> {
        let urlString = "https://api.github.com/repos/ruuvi/ruuvi.firmware.c/releases/latest"
        guard let url = URL(string: urlString)
        else {
            return Fail<GitHubRelease, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        return
            session.firmwareDataPublisher(for: url)
            .decode(type: GitHubRelease.self, decoder: JSONDecoder())
            .catch { error in Fail<GitHubRelease, Error>(error: error) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func serveCurrentRelease(uuid: String) -> Future<CurrentRelease, Error> {
        Future { [weak self] promise in
            guard let self else { return }
            background.services.gatt.firmwareRevision(
                for: self,
                uuid: uuid,
                options: [
                    .connectionTimeout(15),
                    .serviceTimeout(15),
                ]
            ) { _, result in
                switch result {
                case let .success(version):
                    let sanitizedVersion = version.ruuviFirmwareDisplayValue
                    let currentRelease = CurrentRelease(version: sanitizedVersion)
                    promise(.success(currentRelease))
                case let .failure(error):
                    promise(.failure(error))
                }
            }
        }
    }

    func download(release: GitHubRelease) -> AnyPublisher<FirmwareDownloadResponse, Error> {
        guard let fullName = release.defaultFullZipName,
            let fullUrl = release.defaultFullZipUrl
        else {
            return Fail<FirmwareDownloadResponse, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        guard let appName = release.defaultAppZipName,
            let appUrl = release.defaultAppZipUrl
        else {
            return Fail<FirmwareDownloadResponse, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        return downloader.download(assets: [.init(name: appName, url: appUrl), .init(name: fullName, url: fullUrl)])
            .map { event in
                switch event {
                case .progress(let progress): return .progress(progress)
                case .files(let files): return .response(appUrl: files[0], fullUrl: files[1])
                }
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func listen() -> Future<String, Never> {
        Future { [weak self] promise in
            guard let self else { return }
            ruuviDFU.scan(self, includeScanServices: false) { _, device in
                promise(.success(device.uuid))
            }
        }
    }

    func observeLost(uuid: String) -> Future<String, Never> {
        Future { [weak self] promise in
            guard let self else { return }
            ruuviDFU.lost(
                self,
                closure: { _, device in
                    if device.uuid == uuid {
                        promise(.success(uuid))
                    }
                })
        }
    }

    func flash(
        uuid: String,
        latestRelease: GitHubRelease,
        currentRelease: CurrentRelease?,
        appUrl: URL,
        fullUrl: URL
    ) -> AnyPublisher<FlashResponse, Error> {
        let firmwareUrl: URL
        if let currentMajor = currentRelease?.version.semVar?.first,
            let latestMajor = latestRelease.version.semVar?.first,
            currentMajor == latestMajor
        {
            firmwareUrl = appUrl
        } else {
            firmwareUrl = fullUrl
        }

        guard let firmware = ruuviDFU.firmwareFromUrl(url: firmwareUrl)
        else {
            return Fail<FlashResponse, Error>(
                error: FirmwareError.failedToConstructFirmwareFromFile
            ).eraseToAnyPublisher()
        }
        return ruuviDFU.flashFirmware(uuid: uuid, with: firmware).eraseToAnyPublisher()
    }
}
