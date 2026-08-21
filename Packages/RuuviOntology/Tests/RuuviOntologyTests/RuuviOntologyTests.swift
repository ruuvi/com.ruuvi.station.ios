@testable import RuuviOntology
import XCTest

final class RuuviOntologyTests: XCTestCase {
    func testMACSuffixIgnoresPrefixCaseAndSeparators() {
        XCTAssertEqual("AA:BB:CC:DD:EE:FF".macSuffix, "dd:ee:ff")
        XCTAssertEqual("aa-bb-cc-dd-ee-ff".macSuffix, "dd:ee:ff")
        XCTAssertEqual("AA-BB-CC-DD-EE-FF".macSuffix, "dd:ee:ff")
        XCTAssertEqual("C5DDEEFF".macSuffix, "dd:ee:ff")
    }

    func testMACEqualityUsesLastThreeBytes() {
        XCTAssertEqual("C5:DD:EE:FF".mac.any, "AA:BB:CC:DD:EE:FF".mac.any)
        XCTAssertNotEqual("C5:DD:EE:FF".mac.any, "AA:BB:CC:00:11:22".mac.any)
    }

    func testPhysicalSensorIdentityKeyIsStableAcrossOriginalAndCanonicalMACs() {
        let original = PhysicalSensorStruct(luid: nil, macId: "C5:DD:EE:FF".mac)
        let canonical = PhysicalSensorStruct(luid: nil, macId: "AA:BB:CC:DD:EE:FF".mac)

        XCTAssertEqual(original.identityKey, canonical.identityKey)
    }

    func testPhysicalSensorIdentityKeyKeepsMalformedMACExact() {
        let first = PhysicalSensorStruct(luid: nil, macId: "AA:BB".mac)
        let second = PhysicalSensorStruct(luid: nil, macId: "CC:BB".mac)

        XCTAssertNotEqual(first.identityKey, second.identityKey)
    }
}
