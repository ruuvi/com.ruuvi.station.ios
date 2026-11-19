import DGCharts
import Foundation
import RuuviLocal
import RuuviCloud
import RuuviOntology

/// Converts server summaries directly to chart models, without creating BLE records.
enum CloudGraphAdapter {
    private static let metrics: [MeasurementType: CloudGraphMetricName] = [
        .temperature: .temperature, .pressure: .pressure, .voltage: .battery, .rssi: .rssi,
        .movementCounter: .movementCounter, .measurementSequenceNumber: .measurementSequenceNumber,
        .accelerationX: .accelerationX, .accelerationY: .accelerationY, .accelerationZ: .accelerationZ,
        .pm10: .pm10, .pm25: .pm25, .pm40: .pm40, .pm100: .pm100,
        .co2: .co2, .voc: .voc, .nox: .nox, .luminosity: .luminosity, .txPower: .txPower,
        .aqi: .aqi, .soundAverage: .dbAverage, .soundPeak: .dbPeak, .soundInstant: .dbInstant,
    ]

    static func metric(for variant: MeasurementDisplayVariant, settings: RuuviLocalSettings) -> CloudGraphMetricName? {
        if variant.type == .humidity {
            switch variant.resolvedHumidityUnit(default: settings.humidityUnit) {
            case .percent: return .humidity
            case .gm3: return .absoluteHumidity
            case .dew: return .dewPoint
            }
        }
        return metrics[variant.type]
    }

    static func model(
        viewport: CloudGraphViewport,
        variant: MeasurementDisplayVariant,
        settings: RuuviLocalSettings,
        lowerAlertValue: Double? = nil,
        upperAlertValue: Double? = nil,
        showAlertRangeInGraph: Bool = false
    ) -> RuuviGraphViewDataModel? {
        guard let metric = metric(for: variant, settings: settings) else { return nil }
        guard viewport.hasMetric(metric) else { return nil }
        let temperatureUnit = variant.resolvedTemperatureUnit(default: settings.temperatureUnit.unitTemperature)
        let pressureUnit = variant.resolvedPressureUnit(default: settings.pressureUnit)
        func convert(_ value: Double) -> Double {
            switch metric {
            case .temperature, .dewPoint:
                return Measurement(value: value, unit: UnitTemperature.celsius).converted(to: temperatureUnit).value
            case .pressure:
                return Measurement(value: value, unit: UnitPressure.newtonsPerMetersSquared).converted(to: pressureUnit).value
            case .battery, .accelerationX, .accelerationY, .accelerationZ: return value / 1000
            default: return value
            }
        }
        // Use the same dataset and fork renderer as local history. In particular,
        // a lone segment is not a whole one-reading chart. The shared one-hour gap
        // rule draws small gap dots, stems and dashed hints without filling gaps.
        let entries = viewport.segments(metric).flatMap { $0 }.map {
            ChartDataEntry(x: Double($0.timestamp), y: convert($0.value))
        }.sorted { $0.x < $1.x }
        let dataSet = RuuviGraphDataSetFactory.newDataSet(
            upperAlertValue: upperAlertValue, entries: entries,
            lowerAlertValue: lowerAlertValue, showAlertRangeInGraph: showAlertRangeInGraph
        )
        RuuviGraphDataSetFactory.configureCircles(for: dataSet, drawDots: settings.chartDrawDotsOn)
        let model = RuuviGraphViewDataModel(
            upperAlertValue: upperAlertValue, variant: variant,
            chartData: LineChartData(dataSet: dataSet), lowerAlertValue: lowerAlertValue
        )
        model.timelineRange = viewport.timeline.range
        model.summaryStatistics = { range in
            guard let stats = viewport.statistics(metric, in: range) else { return (nil, nil, nil) }
            return (convert(stats.min), convert(stats.max), stats.mean.map(convert))
        }
        return model
    }
}
