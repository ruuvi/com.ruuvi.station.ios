import Combine
import Foundation
import RuuviDFU
@testable import RuuviFirmware

final class FirmwareInteractorSpy: FirmwareInteracting {
    let batteryIsLow = CurrentValueSubject<Bool, Never>(false)
    let releases = PassthroughSubject<GitHubRelease, Error>()
    let downloads = PassthroughSubject<FirmwareDownloadResponse, Error>()
    let flashes = PassthroughSubject<FlashResponse, Error>()
    var currentPromise: Future<CurrentRelease, Error>.Promise?
    var listenPromise: Future<String, Never>.Promise?
    var lostPromise: Future<String, Never>.Promise?
    var checkedBatteries: [String] = []
    var daemonRestarts = 0
    var flashedUUID: String?
    func restartPropertiesDaemon() { daemonRestarts += 1 }
    func ensureBatteryHasEnoughPower(uuid: String) { checkedBatteries.append(uuid) }
    func loadLatestGitHubRelease() -> AnyPublisher<GitHubRelease, Error> { releases.eraseToAnyPublisher() }
    func serveCurrentRelease(uuid: String) -> AnyPublisher<CurrentRelease, Error> {
        Future<CurrentRelease, Error> { self.currentPromise = $0 }.eraseToAnyPublisher()
    }
    func download(release: GitHubRelease) -> AnyPublisher<FirmwareDownloadResponse, Error> {
        downloads.eraseToAnyPublisher()
    }
    func listen() -> AnyPublisher<String, Never> {
        Future<String, Never> { self.listenPromise = $0 }.eraseToAnyPublisher()
    }
    func observeLost(uuid: String) -> AnyPublisher<String, Never> {
        Future<String, Never> { self.lostPromise = $0 }.eraseToAnyPublisher()
    }
    func flash(
        uuid: String, latestRelease: GitHubRelease, currentRelease: CurrentRelease?,
        appUrl: URL, fullUrl: URL
    ) -> AnyPublisher<FlashResponse, Error> {
        flashedUUID = uuid
        return flashes.eraseToAnyPublisher()
    }
}

final class FirmwareOutputSpy: FirmwareViewModelOutput {
    var finished = 0
    func firmwareUpgradeDidFinishSuccessfully() { finished += 1 }
}
