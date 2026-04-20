@testable import RuuviMigration
import RuuviOntology
import XCTest

final class RuuviMigrationTests: XCTestCase {
    func testUserDefaultReturnsDefaultUntilValueIsSet() {
        let key = "RuuviMigrationTests.userDefault.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        var sut = UserDefaultFixture(key: key)

        XCTAssertEqual(sut.value, 240)

        sut.value = 60

        XCTAssertEqual(sut.value, 60)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 60)
    }

    func testOptionalUserDefaultsAccessorsReturnNilForMissingKeysAndValuesForStoredKeys() {
        let suffix = UUID().uuidString
        let intKey = "RuuviMigrationTests.int.\(suffix)"
        let doubleKey = "RuuviMigrationTests.double.\(suffix)"
        let boolKey = "RuuviMigrationTests.bool.\(suffix)"
        defer {
            UserDefaults.standard.removeObject(forKey: intKey)
            UserDefaults.standard.removeObject(forKey: doubleKey)
            UserDefaults.standard.removeObject(forKey: boolKey)
        }

        XCTAssertNil(UserDefaults.standard.optionalInt(forKey: intKey))
        XCTAssertNil(UserDefaults.standard.optionalDouble(forKey: doubleKey))
        XCTAssertNil(UserDefaults.standard.optionalBool(forKey: boolKey))

        UserDefaults.standard.set(240, forKey: intKey)
        UserDefaults.standard.set(60.5, forKey: doubleKey)
        UserDefaults.standard.set(true, forKey: boolKey)

        XCTAssertEqual(UserDefaults.standard.optionalInt(forKey: intKey), 240)
        XCTAssertEqual(UserDefaults.standard.optionalDouble(forKey: doubleKey), 60.5)
        XCTAssertEqual(UserDefaults.standard.optionalBool(forKey: boolKey), true)
    }

    func testCalibrationPersistenceRoundTripsHumidityOffsetAndDate() {
        let sut = CalibrationPersistenceUserDefaults()
        let identifier = UUID().uuidString.luid.any
        let expectedDate = Date(timeIntervalSince1970: 1_700_000_000)

        sut.setHumidity(date: expectedDate, offset: 4.5, for: identifier)

        let stored = sut.humidityOffset(for: identifier)
        XCTAssertEqual(stored.0, 4.5, accuracy: 0.0001)
        XCTAssertEqual(stored.1, expectedDate)

        sut.setHumidity(date: nil, offset: 1.25, for: identifier)

        let overwritten = sut.humidityOffset(for: identifier)
        XCTAssertEqual(overwritten.0, 1.25, accuracy: 0.0001)
        XCTAssertNil(overwritten.1)
    }
}

private struct UserDefaultFixture {
    @UserDefault("", defaultValue: 240)
    private var storedValue: Int
    private let key: String

    init(key: String) {
        self.key = key
        _storedValue = UserDefault(key, defaultValue: 240)
    }

    var value: Int {
        get { storedValue }
        set { storedValue = newValue }
    }
}
