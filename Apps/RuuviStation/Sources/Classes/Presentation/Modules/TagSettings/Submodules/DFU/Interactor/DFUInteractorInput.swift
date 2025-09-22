import BTKit
import Combine
import Foundation
import RuuviDFU
import RuuviOntology

protocol DFUInteractorInput {
    // Async replacements for previous Future-based APIs
    func listen(ruuviTag: RuuviTagSensor) async -> DFUDevice
    func observeLost(uuid: String) -> AsyncStream<String>
    func serveCurrentRelease(for ruuviTag: RuuviTagSensor) async throws -> CurrentRelease

    // Retain Combine publishers (can migrate later if desired)
    func download(release: LatestRelease) -> AnyPublisher<FirmwareDownloadResponse, Error>
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error>
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
