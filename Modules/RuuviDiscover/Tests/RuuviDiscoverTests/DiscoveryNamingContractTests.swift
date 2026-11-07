import RuuviLocalization
import UIKit
import XCTest
@testable import RuuviDiscover

@MainActor final class DiscoveryNamingContractTests: XCTestCase {
    // Characterization of Helpers.swift from main f2c7357f7: identity suffixes and product names are unchanged.
    func testProductNamesPreferTheMacSuffixThenTheBluetoothPrefix() {
        for format: Int? in [nil, 3, 5, 6, 225] {
            let product = (format == 6 || format == 225) ? RuuviLocalization.ruuviAir : RuuviLocalization.ruuviTag
            XCTAssertEqual(
                Helpers.ruuviDeviceDefaultName(from: "AA:BB:CC:DD:12:EF", luid: "Ignored", dataFormat: format),
                product + " 12EF")
            XCTAssertEqual(
                Helpers.ruuviDeviceDefaultName(from: nil, luid: "12345678-ABCD", dataFormat: format),
                product + " 1234")
            XCTAssertEqual(Helpers.ruuviDeviceDefaultName(from: nil, luid: "AB", dataFormat: format), product + " AB")
            XCTAssertEqual(Helpers.ruuviDeviceDefaultName(from: nil, luid: nil, dataFormat: format), product + " ")
        }
        XCTAssertEqual(Helpers.ruuviAirDefaultName(from: "AA:BB:CC:DD:12:EF"), RuuviLocalization.ruuviAir + " 12EF")
    }

    func testReusedDiscoveryCellDoesNotDisplayThePreviousSensorNameOrSignal() {
        let cell = DiscoverDeviceTableViewCell(style: .default, reuseIdentifier: "discovery")
        cell.identifierLabel.text = "Office"
        cell.rssiLabel.text = "-45 dBm"
        cell.rssiImageView.image = UIImage(systemName: "wifi")
        cell.prepareForReuse()
        XCTAssertNil(cell.identifierLabel.text)
        XCTAssertNil(cell.rssiLabel.text)
        XCTAssertNil(cell.rssiImageView.image)
        cell.identifierLabel.text = "Kitchen"
        XCTAssertEqual(cell.identifierLabel.text, "Kitchen")
    }
}
