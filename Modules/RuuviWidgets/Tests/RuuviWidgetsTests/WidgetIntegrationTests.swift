import AppIntents
import Foundation
import RuuviCloud
import RuuviLocal
import RuuviUser
import Swinject
import WidgetKit
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetIntegrationTests: XCTestCase {
    func testProductionAssemblyResolvesEveryRequiredDependencyWithoutNetwork() throws {
        let resolver = WidgetAssembly().assembler.resolver
        XCTAssertNotNil(resolver.resolve(RuuviCloud.self))
        XCTAssertNotNil(resolver.resolve(RuuviUser.self))
        XCTAssertNotNil(resolver.resolve(RuuviLocalIDs.self))
        XCTAssertNotNil(resolver.resolve(RuuviCloudFactory.self))
        XCTAssertNotNil(resolver.resolve(RuuviUserFactory.self))
        XCTAssertNotNil(resolver.resolve(RuuviLocalFactory.self))
        let first = try XCTUnwrap(resolver.resolve(RuuviUser.self)) as AnyObject
        let second = try XCTUnwrap(resolver.resolve(RuuviUser.self)) as AnyObject
        XCTAssertTrue(first === second)
    }

    func testManualRefreshIntentPersistsRequestForEachWidgetKind() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Constants.appGroupBundleId.rawValue))
        let key = Constants.forceRefreshWidgetKey.rawValue
        let saved = defaults.object(forKey: key)
        defer { defaults.set(saved, forKey: key) }
        XCTAssertEqual(WidgetRefresher().target, .simple)
        for target: WidgetRefreshTarget in [.simple, .multi] {
            defaults.set(false, forKey: key)
            _ = try await WidgetRefresher(target: target).perform()
            XCTAssertTrue(defaults.bool(forKey: key))
        }
        XCTAssertEqual(Set(WidgetRefreshTarget.caseDisplayRepresentations.keys), [.simple, .multi])
    }

    func testWidgetKindsAndIntentRuntimeNamesRemainStable() {
        XCTAssertEqual(RuuviSingleSensorWidget().kind, "ruuvi.simpleWidget")
        XCTAssertEqual(RuuviMultiSensorWidget().kind, "ruuvi.multiSensorWidget")
        XCTAssertTrue(NSClassFromString("RuuviTagSelectionIntent") === RuuviTagSelectionIntent.self)
        XCTAssertTrue(NSClassFromString("RuuviMultiSensorSelectionIntent") === RuuviMultiSensorSelectionIntent.self)
        XCTAssertTrue(NSClassFromString("RuuviWidgetTag") === RuuviWidgetTag.self)
        XCTAssertNotNil(
            WidgetResources.bundle.url(forResource: "RuuviWidgetsConfiguration", withExtension: "intentdefinition"))
    }
}
