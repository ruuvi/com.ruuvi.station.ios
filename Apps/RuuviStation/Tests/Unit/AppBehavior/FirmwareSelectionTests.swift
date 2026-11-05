import Combine
import Foundation
import RuuviDFU
import RuuviOntology
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif
import XCTest
@testable import station

final class FirmwareSelectionTests: XCTestCase {
    func testTagUsesAppOnlyForKnownMatchingMajorVersions() {
        let cases: [(String?, String, Bool)] = [
            ("3.9.0", "3.10.0", true), ("v3.9.0-dev", "v3.10.0", true),
            ("2.9.0", "3.10.0", false), (nil, "3.10.0", false),
            ("unknown", "unknown", false), ("unknown", "3.10.0", false),
        ]
        for (current, latest, appOnly) in cases {
            let service = FirmwareSelectionDFU()
            let interactor = DFUInteractor(deviceType: .ruuviTag, firmwareType: .latest)
            interactor.ruuviDFU = service
            let app = URL(fileURLWithPath: "/app.zip")
            let full = URL(fileURLWithPath: "/full.zip")
            let target = device()
            let token = interactor.flash(
                dfuDevice: target, latestRelease: .init(version: latest, assets: []),
                currentRelease: current.map { .init(version: $0) }, appUrl: app, fullUrl: full, additionalFiles: []
            ).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            XCTAssertEqual(service.requestedFirmware, [appOnly ? app : full], "\(current ?? "nil") → \(latest)")
            XCTAssertEqual(service.flashedUUID, target.uuid)
            withExtendedLifetime(token) {}
        }
    }

    func testTagInvalidArchiveFailsBeforeStartingFlash() {
        let service = FirmwareSelectionDFU()
        service.validArchive = false
        let interactor = DFUInteractor(deviceType: .ruuviTag, firmwareType: .latest)
        interactor.ruuviDFU = service
        var failure: Error?
        let token = interactor.flash(
            dfuDevice: device(), latestRelease: .init(version: "3.0.0", assets: []),
            currentRelease: nil, appUrl: URL(fileURLWithPath: "/app.zip"),
            fullUrl: URL(fileURLWithPath: "/full.zip"), additionalFiles: []
        ).sink(receiveCompletion: { if case .failure(let error) = $0 { failure = error } }, receiveValue: { _ in })
        XCTAssertEqual(failure as? station.DFUError, .failedToConstructFirmwareFromFile)
        XCTAssertNil(service.flashedUUID)
        withExtendedLifetime(token) {}
    }

    func testAirUploadsPrimaryThenEachAdditionalFileOnce() {
        let service = FirmwareSelectionDFU()
        let interactor = DFUInteractor(deviceType: .ruuviAir, firmwareType: .latest)
        interactor.ruuviDFU = service
        let app = URL(fileURLWithPath: "/app.bin")
        let loader = URL(fileURLWithPath: "/loader.bin")
        let boot = URL(fileURLWithPath: "/boot.bin")
        let target = device()
        let token = interactor.flash(
            dfuDevice: target, latestRelease: .init(version: "1.0.0", assets: []),
            currentRelease: .init(version: "0.0.1-dev"), appUrl: app, fullUrl: app,
            additionalFiles: [loader, app, loader, boot, boot]
        ).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        XCTAssertEqual(service.files, [app, loader, boot])
        XCTAssertEqual(service.flashedUUID, target.uuid)
        XCTAssertTrue(service.requestedFirmware.isEmpty)
        withExtendedLifetime(token) {}
    }

    private func device() -> DFUDevice {
        let peripheral = SelectionPeripheral()
        return .init(
            uuid: peripheral.identifier.uuidString, rssi: -50, isConnectable: true,
            name: nil, peripheral: peripheral)
    }
}

private final class SelectionPeripheral: DFUPeripheral { let identifier = UUID() }
private final class FirmwareSelectionDFU: RuuviDFU {
    var validArchive = true
    var requestedFirmware: [URL] = []
    var flashedUUID: String?
    var files: [URL] = []
    func scan<T: AnyObject>(
        _ observer: T, includeScanServices: Bool, closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken { .init(cancellationClosure: {}) }
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        .init(cancellationClosure: {})
    }
    func firmwareFromUrl(url: URL) -> DFUFirmware? {
        requestedFirmware.append(url)
        return validArchive ? DFUFirmware(binFile: Data([1]), datFile: nil, type: .application) : nil
    }
    func flashFirmware(uuid: String, with firmware: DFUFirmware) -> AnyPublisher<FlashResponse, Error> {
        flashedUUID = uuid
        return Just(.done).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func flashFirmware(dfuDevice: DFUDevice, with firmwareURL: URL) -> AnyPublisher<FlashResponse, Error> {
        flashFirmware(dfuDevice: dfuDevice, with: [firmwareURL])
    }
    func flashFirmware(dfuDevice: DFUDevice, with firmwareURLs: [URL]) -> AnyPublisher<FlashResponse, Error> {
        flashedUUID = dfuDevice.uuid
        files = firmwareURLs
        return Just(.done).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func stopFlashFirmware(device: DFUDevice) -> Bool { false }
}
