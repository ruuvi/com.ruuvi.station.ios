import UIKit
import RuuviOntology
import RuuviService
import RuuviLocalization
import SwiftUI

final class SnapshotFactory {

    private let measurement: RuuviServiceMeasurement
    private let batteryStatusProvider = RuuviTagBatteryStatusProvider()

    init(measurement: RuuviServiceMeasurement) {
        self.measurement = measurement
    }

    /// Build a snapshot. `record` or `settings` may be `nil`
    func make(
        tag: AnyRuuviTagSensor,
        record: RuuviTagSensorRecord?,
        settings: SensorSettings?
    ) -> SensorSnapshot {
        let name = tag.name

        let indicators: [IndicatorModel] = IndicatorComposer.compose(
            tag: tag,
            record: record,
            settings: settings,
            measurement: measurement
        )

        var sourceIcon: Image?
        if let source = record?.source {
            switch source {
            case .advertisement, .bgAdvertisement:
                sourceIcon = RuuviAsset.iconBluetooth.swiftUIImage
            case .heartbeat, .log:
                sourceIcon = RuuviAsset.iconBluetoothConnected.swiftUIImage
            case .ruuviNetwork:
                sourceIcon = RuuviAsset.iconGateway.swiftUIImage
            default:
                sourceIcon = nil
            }
        }

        let meta = SensorSnapshot.Meta(
            timestamp: record?.date,
            source: record?.source,
            sourceIcon: sourceIcon,
            batteryLow: batteryStatusProvider.batteryNeedsReplacement(
                    temperature: record?.temperature,
                    voltage: record?.voltage
                ),
            alertState: nil
        )

        return SensorSnapshot(
            id: tag.id,
            displayName: name,
            indicators: indicators,
            meta: meta
        )
    }

    /// Update existing snapshot fields without creating new one
    func updateFields(
        in snapshot: inout SensorSnapshot,
        tag: AnyRuuviTagSensor,
        record: RuuviTagSensorRecord?,
        settings: SensorSettings?
    ) -> Bool {
        var hasChanges = false

        // Update display name
        let newDisplayName = tag.name
        if snapshot.displayName != newDisplayName {
            snapshot.displayName = newDisplayName
            snapshot.displayVersion += 1
            hasChanges = true
        }

        // Update indicators
        let newIndicators = IndicatorComposer.compose(
            tag: tag,
            record: record,
            settings: settings,
            measurement: measurement
        )
        if snapshot.indicators != newIndicators {
            snapshot.indicators = newIndicators
            snapshot.indicatorVersion += 1
            hasChanges = true
        }

        // Update meta data
        var newMeta = snapshot.meta

        // Update timestamp
        if newMeta.timestamp != record?.date {
            newMeta.timestamp = record?.date
            snapshot.timestampVersion += 1
            hasChanges = true
        }

        // Update source
        let newSource = record?.source
        var newSourceIcon: Image?
        if let source = newSource {
            switch source {
            case .advertisement, .bgAdvertisement:
                newSourceIcon = RuuviAsset.iconBluetooth.swiftUIImage
            case .heartbeat, .log:
                newSourceIcon = RuuviAsset.iconBluetoothConnected.swiftUIImage
            case .ruuviNetwork:
                newSourceIcon = RuuviAsset.iconGateway.swiftUIImage
            default:
                newSourceIcon = nil
            }
        }

        if newMeta.source != newSource || newMeta.sourceIcon != newSourceIcon {
            newMeta.source = newSource
            newMeta.sourceIcon = newSourceIcon
            snapshot.sourceVersion += 1
            hasChanges = true
        }

        // Update battery status
        let newBatteryLow = batteryStatusProvider.batteryNeedsReplacement(
            temperature: record?.temperature,
            voltage: record?.voltage
        )
        if newMeta.batteryLow != newBatteryLow {
            newMeta.batteryLow = newBatteryLow
            snapshot.batteryVersion += 1
            hasChanges = true
        }

        // Apply meta changes
        if hasChanges {
            snapshot.meta = newMeta
        }

        return hasChanges
    }
}

// MARK: – Composer
enum IndicatorComposer {

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func compose(
        tag: AnyRuuviTagSensor,
        record: RuuviTagSensorRecord?,
        settings: SensorSettings?,
        measurement service: RuuviServiceMeasurement
    ) -> [IndicatorModel]
    {
        let version = RuuviFirmwareVersion.firmwareVersion(from: tag.version)

        // MARK: Formatting
        let temperatureString = record?.temperature.flatMap {
            service.stringWithoutSign(for: $0).components(
                separatedBy: String.nbsp
            ).first
        }

        let pressureString = record?.pressure.flatMap {
            service.stringWithoutSign(for: $0)
        }

        let humidityString: String? = {
            guard let h = record?.humidity else { return nil }
            return service.stringWithoutSign(
                for: h, temperature: record?.temperature
            )
        }()

        // MARK: grid
        var indicators: [IndicatorModel] = []

        // ---- Firmware E0 / F0
        if version == .e0 || version == .f0 {
            // Prominent Indicator - AQI but for Image View only.
            let (current, max, state) = service.aqiString(
                for: record?.co2,
                pm25: record?.pm2_5,
                voc: record?.voc,
                nox: record?.nox
            )
            let progress = Float(current) / Float(max)
            indicators.append(
                .make(
                    kind: .aqi,
                    value: "\(current.stringValue)/\(max.stringValue)",
                    unit: RuuviLocalization.airQuality,
                    maximumValue: max,
                    progress: progress,
                    tint: state.color,
                    prominent: true
                )
            )

            indicators.append(
                .make(
                    kind: .aqiProminent,
                    value: current.stringValue,
                    unit: RuuviLocalization.airQuality,
                    maximumValue: max,
                    progress: progress,
                    tint: state.color,
                    prominent: true
                )
            )

            // Temperature
            if let temperature = temperatureString {
                indicators.append(
                    .make(
                        kind: .temperature,
                        value: temperature,
                        unit: service.units.temperatureUnit.symbol
                    )
                )
            }

            // Humidity
            if let humidity = humidityString {
                let unit = service.units.humidityUnit == .dew
                          ? service.units.temperatureUnit.symbol
                          : service.units.humidityUnit.symbol
                indicators.append(
                    .make(
                        kind: .humidity,
                        value: humidity,
                        unit: unit
                    )
                )
            }

            // Pressure
            if let pressure = pressureString {
                indicators.append(
                    .make(
                        kind: .pressure,
                        value: pressure,
                        unit: service.units.pressureUnit.symbol
                    )
                )
            }

            // E0/F0
            if let co2 = record?.co2.flatMap({
                service.co2String(for: $0)
            }) {
                indicators.append(
                    .make(
                        kind: .co2,
                        value: co2,
                        unit: RuuviLocalization.unitCo2
                    )
                )
            }

            if let pm25 = record?.pm2_5.flatMap({
                service.pm25String(for: $0)
            }) {
                indicators.append(
                    .make(
                        kind: .pm25,
                        value: pm25,
                        unit: RuuviLocalization.unitPm25
                    )
                )
            }

            if let pm10 = record?.pm10.flatMap({
                service.pm10String(for: $0)
            }) {
                indicators.append(
                    .make(
                        kind: .pm10,
                        value: pm10,
                        unit: RuuviLocalization.unitPm10
                    )
                )
            }

            if let nox = record?.nox.flatMap({
                service.noxString(for: $0)
            }) {
                indicators.append(
                    .make(
                        kind: .nox,
                        value: nox,
                        unit: RuuviLocalization.unitNox,
                    )
                )
            }

            if let voc = record?.voc.flatMap({
                service.vocString(for: $0)
            }) {
                indicators.append(
                    .make(
                        kind: .voc,
                        value: voc,
                        unit: RuuviLocalization.unitVoc
                    )
                )
            }

            if let luminosity = record?.luminance.flatMap({
                service.luminosityString(for: $0)
            }) {
                indicators.append(
                    .make(
                        kind: .luminosity,
                        value: luminosity,
                        unit: RuuviLocalization.unitLuminosity,
                    )
                )
            }

            if let soundAvg = record?.dbaAvg.flatMap({
                service.soundAvgString(for: $0)
            }) {
                indicators.append(
                    .make(
                        kind: .soundAvg,
                        value: soundAvg,
                        unit: RuuviLocalization.unitSound,
                    )
                )
            }

            return indicators
        }

        // Firmware V5 or older
        // Prominent = Temperature
        if let temperature = temperatureString {
            indicators.append(
                .make(
                    kind: .temperature,
                    value: temperature,
                    unit: service.units.temperatureUnit.symbol,
                    prominent: true
                )
            )
        }

        // Humidity
        if let humidity = humidityString {
            let unit = service.units.humidityUnit == .dew
                      ? service.units.temperatureUnit.symbol
                      : service.units.humidityUnit.symbol
            indicators.append(
                .make(
                    kind: .humidity,
                    value: humidity,
                    unit: unit
                )
            )
        }

        // Pressure
        if let pressure = pressureString {
            indicators.append(
                .make(
                    kind: .pressure,
                    value: pressure,
                    unit: service.units.pressureUnit.symbol
                )
            )
        }

        // Movement count
        if let move = record?.movementCounter {
            indicators.append(
                .make(
                    kind: .movement,
                    value: "\(move)",
                    unit: RuuviLocalization.Cards.Movements.title
                )
            )
        }

        return indicators
    }
}
