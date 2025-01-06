import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviService

struct ExportHeadersProvider: RuuviServiceExportHeaders {
    func getHeaders(
        version: Int,
        units: RuuviServiceMeasurementSettingsUnit,
        settings: RuuviLocalSettings
    ) -> [String] {
        let tempFormat = RuuviLocalization.ExportService.temperature
        let pressureFormat = RuuviLocalization.ExportService.pressure
        let humidityFormat = RuuviLocalization.ExportService.humidity

        // Common headers for v3/v5/E0/F0
        var headers = [
            RuuviLocalization.ExportService.date,
            tempFormat(units.temperatureUnit.symbol),
            units.humidityUnit == .dew
                ? humidityFormat(units.temperatureUnit.symbol)
                : humidityFormat(units.humidityUnit.symbol),
            pressureFormat(units.pressureUnit.symbol),
            "RSSI" + " (\(RuuviLocalization.dBm))",
            RuuviLocalization.ExportService.voltage,
        ]

        // E0/F0
        if version == 224 || version == 240 {
            headers += [
                RuuviLocalization.aqi + " (%)",
                RuuviLocalization.co2 + " (\(RuuviLocalization.unitCo2))",
                RuuviLocalization.pm1 + " (\(RuuviLocalization.unitPm10))",
                RuuviLocalization.pm25 + " (\(RuuviLocalization.unitPm25))",
                RuuviLocalization.pm4 + " (\(RuuviLocalization.unitPm40))",
                RuuviLocalization.pm10 + " (\(RuuviLocalization.unitPm100))",
                RuuviLocalization.voc + " (\(RuuviLocalization.unitVoc))",
                RuuviLocalization.nox + " (\(RuuviLocalization.unitNox))",
                RuuviLocalization.soundAvg + " (\(RuuviLocalization.unitSound))",
                RuuviLocalization.soundPeak + " (\(RuuviLocalization.unitSound))",
                RuuviLocalization.luminosity + " (\(RuuviLocalization.unitLuminosity))",
            ]
        } else { // v3/v5
            headers += [
                RuuviLocalization.ExportService.accelerationX + " (\(RuuviLocalization.g))",
                RuuviLocalization.ExportService.accelerationY + " (\(RuuviLocalization.g))",
                RuuviLocalization.ExportService.accelerationZ + " (\(RuuviLocalization.g))",
                RuuviLocalization.ExportService.movementCounter + " (\(RuuviLocalization.Cards.Movements.title))",
                RuuviLocalization.ExportService.txPower + " (\(RuuviLocalization.dBm))",
            ]
        }

        // Common for v3/v5/E0/F0
        headers.append(RuuviLocalization.ExportService.measurementSequenceNumber)

        // Flags
        if settings.includeDataSourceInHistoryExport {
            headers.append(RuuviLocalization.ExportService.dataSource)
        }

        return headers
    }
}
