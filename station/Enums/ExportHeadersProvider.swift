import Foundation
import RuuviService

struct ExportHeadersProvider: ExportServiceHeadersProvider {
    func getHeaders(_ units: RuuviServiceMeasurementSettingsUnit) -> [String] {
        let tempFormat = "ExportService.Temperature".localized()
        let pressureFormat = "ExportService.Pressure".localized()
        let dewPointFormat = "ExportService.DewPoint".localized()
        let humidityFormat = "ExportService.Humidity".localized()
        return [
            "ExportService.Date".localized(),
            "ExportService.ISO8601".localized(),
            String(format: tempFormat, units.temperatureUnit.symbol),
            units.humidityUnit == .dew
                ? String(format: dewPointFormat, units.temperatureUnit.symbol)
                : String(format: humidityFormat, units.humidityUnit.symbol),
            String(format: pressureFormat, units.pressureUnit.symbol),
            "ExportService.AccelerationX".localized(),
            "ExportService.AccelerationY".localized(),
            "ExportService.AccelerationZ".localized(),
            "ExportService.Voltage".localized(),
            "ExportService.MovementCounter".localized(),
            "ExportService.MeasurementSequenceNumber".localized(),
            "ExportService.TXPower".localized()
        ]
    }
}
