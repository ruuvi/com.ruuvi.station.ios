import BTKit
import Combine
import Foundation
import RuuviDaemon
import RuuviDFU

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

final class FirmwareInteractor {
    var batteryIsLow = CurrentValueSubject<Bool, Never>(false)
    private let background: BTBackground
    private let foreground: BTForeground
    private let propertiesDaemon: RuuviTagPropertiesDaemon
    private let firmwareRepository: FirmwareRepository
    private let ruuviDFU: RuuviDFU
    private var ruuviTagObservationToken: ObservationToken?

    init(
        background: BTBackground,
        foreground: BTForeground,
        propertiesDaemon: RuuviTagPropertiesDaemon,
        ruuviDFU: RuuviDFU,
        firmwareRepository: FirmwareRepository
    ) {
        self.background = background
        self.foreground = foreground
        self.propertiesDaemon = propertiesDaemon
        self.ruuviDFU = ruuviDFU
        self.firmwareRepository = firmwareRepository
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
                self.batteryIsLow.value = observer.batteryNeedsReplacement(ruuviTag: ruuviTag)
            }
        }
    }

    private func batteryNeedsReplacement(
        ruuviTag: RuuviTag
    ) -> Bool {
        if let temperature = ruuviTag.celsius,
            let voltage = ruuviTag.volts {
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
            URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: GitHubRelease.self, decoder: JSONDecoder())
            .catch { error in Fail<GitHubRelease, Error>(error: error) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func serveCurrentRelease(uuid: String) async throws -> CurrentRelease {
        try await withCheckedThrowingContinuation { continuation in
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
                    continuation.resume(returning: CurrentRelease(version: version))
                case let .failure(error):
                    continuation.resume(throwing: error)
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
        let progress = Progress(totalUnitCount: 2)
        let full = download(url: fullUrl, name: fullName, progress: progress)
        let app = download(url: appUrl, name: appName, progress: progress)
        return app
            .combineLatest(full)
            .map { app, full in
                switch (app, full) {
                case let (.progress(appProgress), .progress):
                    .progress(appProgress)
                case let (.progress(appProgress), .response):
                    .progress(appProgress)
                case let (.response, .progress(fullProgress)):
                    .progress(fullProgress)
                case let (.response(appUrl), .response(fullUrl)):
                    .response(appUrl: appUrl, fullUrl: fullUrl)
                }
            }.eraseToAnyPublisher()
    }

    private func download(url: URL, name: String, progress: Progress) -> AnyPublisher<DownloadResponse, Error> {
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

    func listen() async -> String {
        await withCheckedContinuation { continuation in
            ruuviDFU.scan(self, includeScanServices: false) { _, device in
                continuation.resume(returning: device.uuid)
            }
        }
    }

    func observeLost(uuid: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            ruuviDFU.lost(self, closure: { _, device in
                if device.uuid == uuid {
                    continuation.yield(uuid)
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
        if let currentRelease {
            let currentMajor = currentRelease.version.drop(while: { !$0.isNumber }).prefix(while: { $0 != "." })
            let latestMajor = latestRelease.version.drop(while: { !$0.isNumber }).prefix(while: { $0 != "." })
            if currentMajor == latestMajor {
                firmwareUrl = appUrl
            } else {
                firmwareUrl = fullUrl
            }
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

// MARK: - Bridging helpers (temporary) for existing Combine consumers
extension FirmwareInteractor {
    func serveCurrentReleasePublisher(uuid: String) -> AnyPublisher<CurrentRelease, Error> {
        Deferred { [weak self] in
            Future { promise in
                guard let self else { return }
                Task {
                    do {
                        let current = try await self.serveCurrentRelease(uuid: uuid)
                        promise(.success(current))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }

    func listenPublisher() -> AnyPublisher<String, Never> {
        Deferred { [weak self] in
            Future { promise in
                guard let self else { return }
                Task {
                    let uuid = await self.listen()
                    promise(.success(uuid))
                }
            }
        }.eraseToAnyPublisher()
    }

    func observeLostPublisher(uuid: String) -> AnyPublisher<String, Never> {
        let subject = PassthroughSubject<String, Never>()
        Task { [weak self] in
            guard let self else { return }
            for await value in self.observeLost(uuid: uuid) {
                subject.send(value)
                // Keep streaming; remove break if multiple events desired
                break
            }
            subject.send(completion: .finished)
        }
        return subject.eraseToAnyPublisher()
    }
}
