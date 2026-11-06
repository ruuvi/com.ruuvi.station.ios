import Combine
import XCTest
@testable import RuuviFirmware

@MainActor final class ModuleFirmwareBatteryTests: XCTestCase {
    func testBatteryWarningUsesTemperatureDependentVoltageThresholds() {
        let fixture = ModuleFirmwareFixture()
        let interactor = fixture.interactor()
        interactor.ensureBatteryHasEnoughPower(uuid: "sensor")
        XCTAssertEqual(fixture.battery.map(\.0), ["sensor"])
        for (temperature, voltage, low): (Double?, Double?, Bool) in [
            (20, 2.49, true), (20, 2.5, false), (0, 2.49, true),
            (-1, 2.29, true), (-1, 2.3, false), (-20, 2.29, true),
            (-21, 1.99, true), (-21, 2, false), (nil, 1, false), (20, nil, false),
        ] {
            fixture.battery[0].1(fixture.packet(temperature: temperature, voltage: voltage))
            XCTAssertEqual(interactor.batteryIsLow.value, low, "\(temperature ?? 999), \(voltage ?? 999)")
        }
        interactor.restartPropertiesDaemon()
        XCTAssertEqual(fixture.daemon.starts, 1)
    }

    func testSwitchingSensorsCancelsTheOldBatteryObserverAndRejectsItsLateReadings() {
        let fixture = ModuleFirmwareFixture()
        var interactor: FirmwareInteractor? = fixture.interactor()
        interactor?.ensureBatteryHasEnoughPower(uuid: "first")
        fixture.battery[0].1(fixture.packet(temperature: 20, voltage: 2))
        XCTAssertTrue(interactor?.batteryIsLow.value == true)
        interactor?.ensureBatteryHasEnoughPower(uuid: "second")
        XCTAssertEqual(fixture.batteryCancellations, 1)
        XCTAssertFalse(interactor?.batteryIsLow.value ?? true)
        fixture.battery[0].1(fixture.packet(temperature: 20, voltage: 2))
        XCTAssertFalse(interactor?.batteryIsLow.value ?? true)
        fixture.battery[1].1(fixture.packet(temperature: 20, voltage: 2))
        XCTAssertTrue(interactor?.batteryIsLow.value == true)
        weak var weakInteractor = interactor
        interactor = nil
        XCTAssertNil(weakInteractor)
        XCTAssertEqual(fixture.batteryCancellations, 2)
    }
}
