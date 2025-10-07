import BTKit
import Combine
import Foundation
import RuuviDFU
import RuuviOntology

protocol DFUInteractorInput {
    func listen(ruuviTag: RuuviTagSensor) -> Future<DFUDevice, Never>
    func observeLost(uuid: String) -> Future<String, Never>
    func download(
        release: LatestRelease,
        currentRelease: CurrentRelease?
    ) -> AnyPublisher<
        FirmwareDownloadResponse,
        Error
    >
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error>
    func serveCurrentRelease(for ruuviTag: RuuviTagSensor) -> Future<CurrentRelease, Error>
    func waitForAirDevice(
        ruuviTag: RuuviTagSensor,
        timeout: TimeInterval
    ) -> AnyPublisher<Void, Error>
    // swiftlint:disable:next function_parameter_count
    func flash(
        dfuDevice: DFUDevice,
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?,
        appUrl: URL,
        fullUrl: URL,
        additionalFiles: [URL]
    ) -> AnyPublisher<FlashResponse, Error>
}

enum DFUError: Error {
    case failedToConstructUrl
    case failedToGetLuid
    case failedToGetFirmwareName
    case failedToConstructFirmwareFromFile
    case airDeviceTimeout
}

struct CurrentRelease {
    var version: String

    var isDevBuild: Bool {
        let lowercaseVersion = version.lowercased()
        return lowercaseVersion.contains("-dev") || lowercaseVersion.contains("+dev")
    }
}

enum FirmwareDownloadResponse {
    case progress(Progress)
    case response(appUrl: URL, fullUrl: URL, additionalFiles: [URL])
}
