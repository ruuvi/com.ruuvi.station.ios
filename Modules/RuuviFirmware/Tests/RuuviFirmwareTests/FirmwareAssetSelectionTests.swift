import BTKit
import Combine
import Foundation
import NordicDFU
import RuuviDaemon
import RuuviDFU
@testable import RuuviFirmware
import XCTest

final class FirmwareAssetSelectionTests: XCTestCase {
    func testApplicationOnlyArchiveRequiresKnownMatchingMajorVersions() {
        let dfu = ArchiveSelectionDFU()
        let interactor = FirmwareInteractor(
            background: BTKit.background, foreground: BTKit.foreground,
            propertiesDaemon: ArchiveSelectionDaemon(), ruuviDFU: dfu, firmwareRepository: FirmwareRepositoryImpl())
        let app = URL(fileURLWithPath: "/application.zip")
        let full = URL(fileURLWithPath: "/full.zip")
        for (current, latest, sameMajor): (String?, String, Bool) in [
            ("3.9.0", "3.10.0", true), ("v3.9.0-dev", "3.10.0", true),
            ("2.9.0", "3.10.0", false), ("unknown", "unknown", false),
            (nil, "3.10.0", false),
        ] {
            let token = interactor.flash(
                uuid: UUID().uuidString, latestRelease: .init(version: latest, assets: []),
                currentRelease: current.map { .init(version: $0) }, appUrl: app, fullUrl: full
            ).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            XCTAssertEqual(dfu.requested, sameMajor ? app : full)
            withExtendedLifetime(token) {}
        }
    }
}

private final class ArchiveSelectionDaemon: RuuviTagPropertiesDaemon {
    func start() {}
    func stop() {}
}
private final class ArchiveSelectionDFU: RuuviDFU {
    var requested: URL?
    func firmwareFromUrl(url: URL) -> DFUFirmware? { requested = url; return nil }
    func scan<T: AnyObject>(
        _ observer: T, includeScanServices: Bool, closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken { .init(cancellationClosure: {}) }
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        .init(cancellationClosure: {})
    }
    func flashFirmware(uuid: String, with firmware: DFUFirmware) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }
    func flashFirmware(dfuDevice: DFUDevice, with firmwareURL: URL) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }
    func stopFlashFirmware(device: DFUDevice) -> Bool { false }
}
