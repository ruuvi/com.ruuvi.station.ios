import BTKit
import Combine
import Foundation
import RuuviDFU
import RuuviFirmware
import RuuviOntology

final class DFUInteractor {
    var ruuviDFU: RuuviDFU!
    var background: BTBackground!
    private let firmwareRepository: FirmwareRepository = FirmwareRepositoryImpl()
    private var timer: Timer?
    private var timeoutDuration: Double = 15
}

extension DFUInteractor: DFUInteractorInput {
    func flash(
        uuid: String,
        latestRelease: LatestRelease,
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
            return Fail<FlashResponse, Error>(error: DFUError.failedToConstructFirmwareFromFile).eraseToAnyPublisher()
        }
        return ruuviDFU.flashFirmware(uuid: uuid, with: firmware).eraseToAnyPublisher()
    }

    func read(release: LatestRelease) -> AnyPublisher<(appUrl: URL, fullUrl: URL), Error> {
        guard let fullName = release.defaultFullZipName
        else {
            return Fail<(appUrl: URL, fullUrl: URL), Error>(
                error: DFUError.failedToGetFirmwareName
            ).eraseToAnyPublisher()
        }
        guard let appName = release.defaultAppZipName
        else {
            return Fail<(appUrl: URL, fullUrl: URL), Error>(
                error: DFUError.failedToGetFirmwareName
            ).eraseToAnyPublisher()
        }
        let app = firmwareRepository.read(name: appName)
        let full = firmwareRepository.read(name: fullName)
        return app
            .combineLatest(full)
            .map { app, full in
                (appUrl: app, fullUrl: full)
            }.eraseToAnyPublisher()
    }

    func download(release: LatestRelease) -> AnyPublisher<FirmwareDownloadResponse, Error> {
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
        let urlString = "https://api.github.com/repos/ruuvi/ruuvi.firmware.c/releases/latest"
        guard let url = URL(string: urlString)
        else {
            return Fail<LatestRelease, Error>(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        return
            URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: LatestRelease.self, decoder: JSONDecoder())
            .catch { error in Fail<LatestRelease, Error>(error: error) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
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
                options: [.connectionTimeout(15)]
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

    func listen() -> Future<String, Never> {
        Future { [weak self] promise in
            guard let sSelf = self else { return }
            sSelf.ruuviDFU.scan(sSelf) { _, device in
                promise(.success(device.uuid))
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
}
