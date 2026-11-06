import BTKit
import Combine
import Foundation
import RuuviDaemon
import RuuviDFU
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviPresenters
import RuuviStorage
import Swinject
import XCTest
@testable import station

@MainActor final class FirmwareLifetimeTests: XCTestCase {
    func testClosingFirmwareScreenReleasesViewModelAndOutput() async throws {
        let resolver = AppAssembly.shared.assembler.resolver
        let sensor = RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: UUID().uuidString.luid, macId: nil,
            serviceUUID: nil, isConnectable: true, name: "Firmware test", isClaimed: false,
            isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: false,
            canShare: false, sharedTo: [], maxHistoryDays: nil)
        let activity = FirmwareActivitySpy()
        var model: DFUViewModel? = DFUViewModel(
            interactor: IdleFirmwareInteractor(), foreground: BTKit.foreground,
            idPersistence: try XCTUnwrap(resolver.resolve(RuuviLocalIDs.self)),
            sqiltePersistence: try XCTUnwrap(resolver.resolve(RuuviPersistence.self, name: "sqlite")),
            ruuviTag: sensor, ruuviPool: try XCTUnwrap(resolver.resolve(RuuviPool.self)),
            ruuviStorage: try XCTUnwrap(resolver.resolve(RuuviStorage.self)),
            settings: try XCTUnwrap(resolver.resolve(RuuviLocalSettings.self)),
            propertiesDaemon: try XCTUnwrap(resolver.resolve(RuuviTagPropertiesDaemon.self)),
            activityPresenter: activity)
        weak var weakModel = model
        var output: FirmwareLifetimeOutput? = FirmwareLifetimeOutput()
        weak var weakOutput = output
        model?.output = output
        model?.finish()
        XCTAssertEqual(output?.finished, 1)
        model?.isLoading = true
        XCTAssertEqual(activity.loading, 1)
        model?.isLoading = false
        XCTAssertEqual(activity.dismissed, 1)
        output = nil
        XCTAssertNil(weakOutput, "Closing output must not be retained by the firmware view model")
        model = nil
        await Task.yield()
        XCTAssertNil(weakModel, "Combine must not retain the firmware screen after it closes")
    }
}

private final class FirmwareLifetimeOutput: DFUViewModelOutput {
    var finished = 0
    func firmwareUpgradeDidFinishSuccessfully() { finished += 1 }
}

private final class FirmwareActivitySpy: ActivityPresenter {
    var loading = 0
    var dismissed = 0
    func show(with state: ActivityPresenterState, atPosition position: ActivityPresenterPosition) { loading += 1 }
    func update(with state: ActivityPresenterState) {}
    func dismiss(immediately: Bool) { dismissed += 1 }
}

final class IdleFirmwareInteractor: DFUInteractorInput {
    func listen(ruuviTag: RuuviTagSensor) -> AnyPublisher<DFUDevice, Never> {
        Future<DFUDevice, Never> { _ in }.eraseToAnyPublisher()
    }
    func observeLost(uuid: String) -> AnyPublisher<String, Never> {
        Future<String, Never> { _ in }.eraseToAnyPublisher()
    }
    func download(release: LatestRelease, currentRelease: CurrentRelease?) -> AnyPublisher<
        FirmwareDownloadResponse, Error
    > {
        Empty().eraseToAnyPublisher()
    }
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error> { Empty().eraseToAnyPublisher() }
    func serveCurrentRelease(for ruuviTag: RuuviTagSensor) -> AnyPublisher<CurrentRelease, Error> {
        Future<CurrentRelease, Error> { _ in }.eraseToAnyPublisher()
    }
    func waitForAirDevice(ruuviTag: RuuviTagSensor, timeout: TimeInterval) -> AnyPublisher<Void, Error> {
        Empty().eraseToAnyPublisher()
    }
    // swiftlint:disable:next function_parameter_count
    func flash(
        dfuDevice: DFUDevice, latestRelease: LatestRelease, currentRelease: CurrentRelease?,
        appUrl: URL, fullUrl: URL, additionalFiles: [URL]
    ) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }
}
