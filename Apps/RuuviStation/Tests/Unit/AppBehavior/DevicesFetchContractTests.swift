import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class DevicesFetchContractTests: XCTestCase {
    func testFetchForwardsExactTokenMetadataAndExposesErrorsInsteadOfAnEmptySuccess() async {
        let service = DeviceTokenServiceSpy()
        let output = DeviceFetchOutputSpy()
        let interactor = DevicesInteractor()
        interactor.presenter = output
        interactor.ruuviServiceCloudNotification = service
        service.result = [RuuviCloudPNTokenStruct(id: 71, lastAccessed: 123, name: "Phone 🌿")]
        interactor.fetchDevices()
        await waitForAppState("tokens fetched") { output.updates.count == 1 }
        XCTAssertEqual(output.updates.first?.map(\.id), [71])
        XCTAssertEqual(output.updates.first?.first?.name, "Phone 🌿")
        XCTAssertEqual(output.updates.first?.first?.lastAccessed, 123)
        XCTAssertTrue(output.errors.isEmpty)
        service.failure = .failedToParseNetworkResponse
        interactor.fetchDevices()
        await waitForAppState("device fetch error") { output.errors.count == 1 }
        XCTAssertEqual(output.updates.count, 1)
        XCTAssertEqual(service.fetches, 2)
        XCTAssertTrue(output.callbacksWereMainThread)
    }

    func testLateTokenResponseDoesNotRetainOrNotifyAReleasedInteractor() async {
        let service = DeviceTokenServiceSpy()
        let output = DeviceFetchOutputSpy()
        var release: CheckedContinuation<Void, Never>?
        service.beforeList = { await withCheckedContinuation { release = $0 } }
        var interactor: DevicesInteractor? = DevicesInteractor()
        interactor?.presenter = output
        interactor?.ruuviServiceCloudNotification = service
        interactor?.fetchDevices()
        await waitForAppState("token request pending") { release != nil }
        weak var released = interactor
        interactor = nil
        XCTAssertNil(released)
        release?.resume()
        await waitForAppState("token request completed") { service.completions == 1 }
        await flushAppBindings()
        XCTAssertTrue(output.updates.isEmpty)
        XCTAssertTrue(output.errors.isEmpty)
    }
}
private final class DeviceFetchOutputSpy: DevicesInteractorOutput {
    var updates = [[RuuviCloudPNToken]]()
    var errors = [RUError]()
    var callbacksWereMainThread = true
    func interactorDidUpdate(tokens: [RuuviCloudPNToken]) {
        updates.append(tokens); callbacksWereMainThread = callbacksWereMainThread && Thread.isMainThread
    }
    func interactorDidError(_ error: RUError) {
        errors.append(error); callbacksWereMainThread = callbacksWereMainThread && Thread.isMainThread
    }
}
@MainActor private final class DeviceTokenServiceSpy: RuuviServiceCloudNotification {
    var result = [RuuviCloudPNToken]()
    var failure: RuuviServiceError?
    var fetches = 0
    var completions = 0
    var beforeList: (() async -> Void)?
    func listTokens() async throws(RuuviServiceError) -> [RuuviCloudPNToken] {
        fetches += 1
        await beforeList?()
        completions += 1
        if let failure { throw failure }
        return result
    }
    func set(token: String?, name: String?, data: String?, language: Language, sound: RuuviAlertSound)
        async throws(RuuviServiceError) -> Int
    { XCTFail("Unexpected registration"); return 0 }
    func set(sound: RuuviAlertSound, language: Language, deviceName: String?) async throws(RuuviServiceError) -> Int {
        XCTFail("Unexpected registration"); return 0
    }
    func register(token: String, type: String, name: String?, data: String?, params: [String: String]?)
        async throws(RuuviServiceError) -> Int
    { XCTFail("Unexpected registration"); return 0 }
    func unregister(token: String?, tokenId: Int?) async throws(RuuviServiceError) -> Bool {
        XCTFail("Unexpected unregister"); return false
    }
}
