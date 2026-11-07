import CoreLocation
import Foundation
import XCTest
@testable import RuuviOntology

final class OntologyPreferenceContractTests: XCTestCase {
    func testExplicitTemperaturePreferenceOverridesTheLocaleAndUnknownValuesUseItsMeasurementSystem() throws {
        let suite = "TemperaturePreferences." + UUID().uuidString
        let defaults = IsolatedTemperatureDefaults(domain: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        for (text, expected): (String, TemperatureUnit) in [
            (" Fahrenheit ", .fahrenheit), ("F", .fahrenheit), ("CELSIUS", .celsius),
            (" c ", .celsius), ("Kelvin", .kelvin), ("K", .kelvin),
        ] {
            defaults.set(text, forKey: "AppleTemperatureUnit")
            for locale in [Locale(identifier: "en_US"), Locale(identifier: "en_GB")] {
                XCTAssertEqual(
                    TemperatureUnit.defaultFromSystemPreferences(userDefaults: defaults, locale: locale), expected)
                XCTAssertEqual(
                    UnitTemperature.defaultFromSystemPreferences(userDefaults: defaults, locale: locale),
                    expected.unitTemperature)
            }
        }
        for value: String? in [nil, "unknown", ""] {
            defaults.set(value, forKey: "AppleTemperatureUnit")
            XCTAssertEqual(
                TemperatureUnit.defaultFromSystemPreferences(
                    userDefaults: defaults, locale: Locale(identifier: "en_US")), .fahrenheit)
            for locale in ["en_GB", "fi_FI", "nb_NO"] {
                XCTAssertEqual(
                    TemperatureUnit.defaultFromSystemPreferences(
                        userDefaults: defaults, locale: Locale(identifier: locale)), .celsius)
            }
        }
    }

    func testTemperatureAlertLimitsRepresentTheSamePhysicalRangeInAllUnits() {
        for (unit, lower, upper): (TemperatureUnit, Double, Double) in [
            (.celsius, -40, 85), (.fahrenheit, -40, 185), (.kelvin, 233.15, 358.15),
        ] {
            XCTAssertEqual(unit.alertRange.lowerBound, lower, accuracy: 0.0001)
            XCTAssertEqual(unit.alertRange.upperBound, upper, accuracy: 0.0001)
            XCTAssertFalse(unit.symbol.isEmpty)
        }
    }

    func testLocationLabelsAvoidMissingComponentPlaceholdersAndPreferTheStateInDescriptions() {
        let cases: [(LocationContractValue, (short: String?, full: String?))] = [
            (.init(city: nil, state: nil, country: nil), (nil, nil)),
            (.init(city: "Oslo", state: nil, country: nil), ("Oslo", "Oslo")),
            (.init(city: nil, state: "Uusimaa", country: nil), (nil, "Uusimaa")),
            (.init(city: nil, state: nil, country: "Finland"), ("Finland", "Finland")),
            (.init(city: "Espoo", state: nil, country: "Finland"), ("Espoo, Finland", "Espoo, Finland")),
            (.init(city: "Espoo", state: "Uusimaa", country: "Finland"), ("Espoo, Finland", "Espoo, Uusimaa")),
            (.init(city: nil, state: "Uusimaa", country: "Finland"), ("Finland", "Uusimaa")),
        ]
        for (location, expected) in cases {
            XCTAssertEqual(location.cityCommaCountry, expected.short)
            XCTAssertEqual(location.description, expected.full)
        }
    }

    func testPreferredOrderPreservesUnknownItemsAndDuplicateSensorIdentitiesWithoutMutatingTheInput() {
        let input = [
            OrderContractValue(id: "unknown", name: "one"), .init(id: "A", name: "two"),
            .init(id: "B", name: "three"), .init(id: "A", name: "four"), .init(id: "later", name: "five"),
        ]
        XCTAssertEqual(input.reorder(by: ["B", "A", "A"]).map(\.name), ["three", "two", "four", "one", "five"])
        XCTAssertEqual(input.reorder(by: []).map(\.name), ["one", "two", "three", "four", "five"])
        XCTAssertEqual(input.reorder(by: ["missing"]).map(\.name), input.map(\.name))
        XCTAssertEqual(input.map(\.name), ["one", "two", "three", "four", "five"])
    }
}
private struct LocationContractValue: Location {
    let city: String?
    let state: String?
    let country: String?
    var coordinate: CLLocationCoordinate2D { .init(latitude: 0, longitude: 0) }
}
private struct OrderContractValue: Reorderable {
    let id: String
    let name: String
    var orderElement: String { id }
}

// A named suite still inherits AppleTemperatureUnit from the simulator's global domain.
// Read only this test's domain so an absent preference remains absent.
private final class IsolatedTemperatureDefaults: UserDefaults, @unchecked Sendable {
    private let domain: String
    init(domain: String) {
        self.domain = domain
        super.init(suiteName: domain)!
    }
    override func string(forKey defaultName: String) -> String? {
        persistentDomain(forName: domain)?[defaultName] as? String
    }
}
