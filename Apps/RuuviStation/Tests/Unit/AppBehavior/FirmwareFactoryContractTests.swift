import RuuviOntology
import SwiftUI
import XCTest
@testable import station

@MainActor final class FirmwareFactoryContractTests: XCTestCase {
    func testRealFactoryBuildsIdleFirmwareScreensForBothTagAndAirWithoutStartingAnUpdate() throws {
        let measurements = MeasurementFixture()
        defer { measurements.cleanup() }
        for version in [5, 6, 225] {
            let sensor = measurements.sensor.with(version: version)
            let module = DFUModuleFactoryImpl().create(for: sensor)
            let view = try XCTUnwrap(module.viewController as? UIHostingController<DFUUIView>)
            XCTAssertTrue(module.viewController === view, "A module must retain its current screen identity")
            let model = view.rootView.viewModel
            XCTAssertEqual(model.isRuuviAir(), version != 5)
            guard case .idle = model.state else { return XCTFail("Creating the route must not start firmware work") }
            XCTAssertFalse(model.isLoading)
            XCTAssertEqual(model.downloadProgress, 0)
            XCTAssertEqual(model.flashProgress, 0)
            XCTAssertTrue(module.isSafeToDismiss())
            XCTAssertTrue(model.output === module)
        }
    }
}
