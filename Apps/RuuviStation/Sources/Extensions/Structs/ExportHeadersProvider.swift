import Foundation
import RuuviLocalization
import RuuviService

struct ExportHeadersProvider: RuuviServiceExportHeaders {
    func getHeaders(_ units: RuuviServiceMeasurementSettingsUnit) -> [String] {
        let tempFormat = RuuviLocalization.ExportService.temperature
        let pressureFormat = RuuviLocalization.ExportService.pressure
        let humidityFormat = RuuviLocalization.ExportService.humidity
        return [
            RuuviLocalization.ExportService.date,
            tempFormat(units.temperatureUnit.symbol),
            units.humidityUnit == .dew
                ? humidityFormat(units.temperatureUnit.symbol)
                : humidityFormat(units.humidityUnit.symbol),
            pressureFormat(units.pressureUnit.symbol),
            "RSSI" + " (\(RuuviLocalization.dBm))",
            RuuviLocalization.ExportService.accelerationX + " (\(RuuviLocalization.g))",
            RuuviLocalization.ExportService.accelerationY + " (\(RuuviLocalization.g))",
            RuuviLocalization.ExportService.accelerationZ + " (\(RuuviLocalization.g))",
            RuuviLocalization.ExportService.voltage,
            RuuviLocalization.ExportService.movementCounter + " (\(RuuviLocalization.Cards.Movements.title))",
            RuuviLocalization.ExportService.measurementSequenceNumber,
            RuuviLocalization.ExportService.txPower + " (\(RuuviLocalization.dBm))",
        ]
    }
}
