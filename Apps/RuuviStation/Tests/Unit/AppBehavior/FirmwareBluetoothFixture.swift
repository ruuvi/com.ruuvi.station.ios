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
@testable import station

@MainActor final class FirmwareBluetoothFixture {
    let measurements = MeasurementFixture()
    let pool = AppPoolSpy()
    let radio = FirmwareRadioSpy()
    var sensor: RuuviTagSensorStruct
    var reads = [(String, (Result<String, Error>) -> Void)]()
    var scans = [(RuuviTagSensorRecord) -> Void]()
    var cancelledScans = 0
    init() { sensor = measurements.sensor; pool.allowSensorUpdates = true }
    func interactor(device: RuuviDeviceType = .ruuviAir, timeout: TimeInterval = 1, delay: TimeInterval = 0)
        -> DFUInteractor
    {
        let interactor = DFUInteractor(
            deviceType: device, firmwareType: .latest, timeoutDuration: timeout,
            airScanDelay: delay,
            firmwareRevision: { [weak self] uuid, callback in self?.reads.append((uuid, callback)) },
            airScan: { [weak self] callback in
                self?.scans.append(callback)
                return { [weak self] in self?.cancelledScans += 1 }
            })
        interactor.ruuviDFU = radio
        interactor.ruuviPool = pool
        interactor.ruuviStorage = measurements.storage
        measurements.storage.oneSensors = [sensor.id: sensor.any]
        return interactor
    }
    func device(uuid: String? = nil) -> DFUDevice {
        let peripheral = FirmwareRadioPeripheral()
        return .init(
            uuid: uuid ?? sensor.luid!.value, rssi: -50, isConnectable: true, name: "Ruuvi",
            peripheral: peripheral)
    }
    func cleanup() { measurements.cleanup() }
}

private final class FirmwareRadioPeripheral: DFUPeripheral { let identifier = UUID() }

final class FirmwareRadioSpy: RuuviDFU {
    var scans = [(Bool, (DFUDevice) -> Void)]()
    var lost = [(DFUDevice) -> Void]()
    var scanCancellations = [Int]()
    var lostCancellations = [Int]()
    func scan<T: AnyObject>(
        _ observer: T, includeScanServices: Bool,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken {
        let index = scans.count
        scans.append(
            (
                includeScanServices,
                { [weak observer] device in
                    if let observer { closure(observer, device) }
                }
            ))
        return .init { [weak self] in self?.scanCancellations.append(index) }
    }
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        let index = lost.count
        lost.append { [weak observer] device in if let observer { closure(observer, device) } }
        return .init { [weak self] in self?.lostCancellations.append(index) }
    }
    func firmwareFromUrl(url: URL) -> DFUFirmware? { nil }
    func flashFirmware(uuid: String, with firmware: DFUFirmware) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }
    func flashFirmware(dfuDevice: DFUDevice, with firmwareURL: URL) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }
    func stopFlashFirmware(device: DFUDevice) -> Bool { false }
}
