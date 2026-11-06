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
    func serveCurrentRelease(uuid: String) -> AnyPublisher<CurrentRelease, Error>
    func download(release: GitHubRelease) -> AnyPublisher<FirmwareDownloadResponse, Error>
    func listen() -> AnyPublisher<String, Never>
    func observeLost(uuid: String) -> AnyPublisher<String, Never>
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
    private var cancelBatteryObservation: (() -> Void)?
    private var batteryGeneration = UUID()
    private let observeBattery: ((String, @escaping (RuuviTag) -> Void) -> (() -> Void))?
    private let firmwareRevision: ((String, @escaping (Result<String, Error>) -> Void) -> Void)?
    private let revisionTimeout: TimeInterval

    init(
        background: BTBackground,
        foreground: BTForeground,
        propertiesDaemon: RuuviTagPropertiesDaemon,
        ruuviDFU: RuuviDFU,
        firmwareRepository: FirmwareRepository,
        session: URLSession = .shared,
        observeBattery: ((String, @escaping (RuuviTag) -> Void) -> (() -> Void))? = nil,
        firmwareRevision: ((String, @escaping (Result<String, Error>) -> Void) -> Void)? = nil,
        revisionTimeout: TimeInterval = 15
    ) {
        self.background = background
        self.foreground = foreground
        self.propertiesDaemon = propertiesDaemon
        self.ruuviDFU = ruuviDFU
        self.session = session
        self.observeBattery = observeBattery
        self.firmwareRevision = firmwareRevision
        self.revisionTimeout = revisionTimeout
        downloader = FirmwareDownloader(session: session, repository: firmwareRepository)
    }

    deinit {
        cancelBatteryObservation?()
    }

    func restartPropertiesDaemon() {
        propertiesDaemon.start()
    }

    func ensureBatteryHasEnoughPower(uuid: String) {
        cancelBatteryObservation?()
        let generation = UUID()
        batteryGeneration = generation
        batteryIsLow.value = false
        let receive: (RuuviTag) -> Void = { [weak self] tag in
            let deliver = { [weak self] in
                guard let self, self.batteryGeneration == generation else { return }
                self.batteryIsLow.value = self.batteryNeedsReplacement(ruuviTag: tag)
            }
            if Thread.isMainThread { deliver() } else { DispatchQueue.main.async(execute: deliver) }
        }
        if let observeBattery {
            cancelBatteryObservation = observeBattery(uuid, receive)
        } else {
            let token = foreground.observe(self, uuid: uuid) { _, device in
                if let tag = device.ruuvi?.tag { receive(tag) }
            }
            cancelBatteryObservation = { token.invalidate() }
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

    func serveCurrentRelease(uuid: String) -> AnyPublisher<CurrentRelease, Error> {
        firmwareObservation(timeout: (revisionTimeout, BTError.logic(.connectionTimedOut) as Error)) { [self] complete in
            let receive: (Result<String, Error>) -> Void = { result in
                complete(result.map { CurrentRelease(version: $0.ruuviFirmwareDisplayValue) })
            }
            if let firmwareRevision {
                firmwareRevision(uuid, receive)
            } else {
                background.services.gatt.firmwareRevision(
                    for: self, uuid: uuid,
                    options: [.connectionTimeout(revisionTimeout), .serviceTimeout(revisionTimeout)]
                ) { _, result in receive(result.mapError { $0 as Error }) }
            }
            return nil
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

    func listen() -> AnyPublisher<String, Never> {
        firmwareObservation { [self] complete in
            let token = ruuviDFU.scan(self, includeScanServices: false) { _, device in
                complete(.success(device.uuid))
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
