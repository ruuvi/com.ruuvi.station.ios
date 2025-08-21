import BTKit
import Combine
import Foundation
import RuuviDFU
import RuuviOntology

protocol DFUInteractorInput {
    func listen(ruuviTag: RuuviTagSensor) -> Future<DFUDevice, Never>
    func observeLost(uuid: String) -> Future<String, Never>
    func read(release: LatestRelease) -> AnyPublisher<(appUrl: URL, fullUrl: URL), Error>
    func download(release: LatestRelease) -> AnyPublisher<FirmwareDownloadResponse, Error>
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error>
    func serveCurrentRelease(for ruuviTag: RuuviTagSensor) -> Future<CurrentRelease, Error>
    func flash(
        dfuDevice: DFUDevice,
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?,
        appUrl: URL,
        fullUrl: URL
    ) -> AnyPublisher<FlashResponse, Error>
}

enum DFUError: Error {
    case failedToConstructUrl
    case failedToGetLuid
    case failedToGetFirmwareName
    case failedToConstructFirmwareFromFile
}

struct CurrentRelease {
    var version: String
}

enum FirmwareDownloadResponse {
    case progress(Progress)
    case response(appUrl: URL, fullUrl: URL)
}
