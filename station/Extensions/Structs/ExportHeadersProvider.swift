import Foundation
import RuuviService

struct ExportHeadersProvider: RuuviServiceExportHeaders {
    func getHeaders(_ units: RuuviServiceMeasurementSettingsUnit) -> [String] {
        let tempFormat = "ExportService.Temperature".localized()
        let pressureFormat = "ExportService.Pressure".localized()
        let humidityFormat = "ExportService.Humidity".localized()
        return [
            "ExportService.Date".localized(),
            String(format: tempFormat, units.temperatureUnit.symbol),
            units.humidityUnit == .dew
                ? String(format: humidityFormat, units.temperatureUnit.symbol)
                : String(format: humidityFormat, units.humidityUnit.symbol),
            String(format: pressureFormat, units.pressureUnit.symbol),
            "RSSI" + " (\("dBm".localized()))",
            "ExportService.AccelerationX".localized() + " (\("g".localized()))",
            "ExportService.AccelerationY".localized() + " (\("g".localized()))",
            "ExportService.AccelerationZ".localized() + " (\("g".localized()))",
            "ExportService.Voltage".localized(),
            "ExportService.MovementCounter".localized() + " (\("Cards.Movements.title".localized()))",
            "ExportService.MeasurementSequenceNumber".localized(),
            "ExportService.TXPower".localized() + " (\("dBm".localized()))"
        ]
    }
}
