import UIKit
import RuuviOntology
import RuuviService
import RuuviLocalization
import SwiftUI

/// Produces `SensorSnapshot`s from the raw domain objects.
/// Pure function – no side effects.
final class SnapshotFactory {

    private let measurement: RuuviServiceMeasurement
    private let relativeFormatter = RelativeDateTimeFormatter()
    private let batteryStatusProvider = RuuviTagBatteryStatusProvider()

    init(measurement: RuuviServiceMeasurement) {
        self.measurement = measurement
        relativeFormatter.unitsStyle = .short
    }

    /// Build a snapshot. `record` or `settings` may be `nil`
    /// (used during first load so cells never start blank).
    func make(tag: AnyRuuviTagSensor,
              record: RuuviTagSensorRecord?,
              settings: SensorSettings?) -> SensorSnapshot {

        // ------------------------------------------------------------------
        // 1.  Name
        let name = tag.name

        // ------------------------------------------------------------------
        // 2. Grid indicators
        let indicators: [IndicatorModel] = IndicatorComposer.compose(
            tag: tag,
            record: record,
            settings: settings,
            measurement: measurement
        )

        // ------------------------------------------------------------------
        // 3. Meta
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
            updatedAt: record?.date.ruuviAgo(),
            timestamp: record?.date,
            source: record?.source,
            sourceIcon: sourceIcon,
            batteryLow: batteryStatusProvider.batteryNeedsReplacement(
                    temperature: record?.temperature,
                    voltage: record?.voltage
                ),
            alertState: nil
        )

        // ------------------------------------------------------------------
        // 4. Snapshot
        return SensorSnapshot(id: tag.macId!.value,
                              displayName: name,
                              background: nil,
                              indicators: indicators,
                              meta: meta,
                              displayVersion: 0)
    }
}

// MARK: – Composer
enum IndicatorComposer {

    // Returns **all** indicators for a tag in the order the cell logic needs.
    // The array will always contain **one** `isProminent == true` item first.

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func compose(
        tag: AnyRuuviTagSensor,
        record: RuuviTagSensorRecord?,
        settings: SensorSettings?,
        measurement m: RuuviServiceMeasurement
    ) -> [IndicatorModel]
    {
        let version = tag.version

        // helpers -----------
        func na() -> String { RuuviLocalization.na }                // "—"
        func str(_ s: String?) -> String { s ?? na() }

        // formatted shortcuts
        let tempStr    = record?.temperature.flatMap {
            m.stringWithoutSign(for: $0)
                .components(separatedBy: String.nbsp).first
        }
        let pressureStr = record?.pressure   .flatMap { m.stringWithoutSign(for: $0) }
        let humidityStr: String? = {
            guard let h = record?.humidity else { return nil }
            return m.stringWithoutSign(for: h, temperature: record?.temperature)
        }()

        // PROMINENT + GRID ------------------------------------------------
        var out: [IndicatorModel] = []

        // ---- Firmware E0 / F0 (version 224 / 240) ---------------------
        if version == 224 || version == 240 {

            // Prominent AQI ------------------------------------------------
            let (cur, max, state) = m.aqiString(for: record?.co2,
                                                   pm25: record?.pm2_5,
                                                   voc: record?.voc,
                                                   nox: record?.nox)
                let progress = Float(cur) / Float(max)
                out.append(.make(kind: .aqi,
                                 title: RuuviLocalization.airQuality,
                                 value: cur.stringValue,
                                 unit: "/\(max.stringValue)",
                                 progress: progress,
                                 tint: state.color,
                                 prominent: true))

            // Temperature
            if let v = tempStr {
                out.append(.make(kind: .temperature,
                                 title: "Temp",
                                 value: v,
                                 unit: m.units.temperatureUnit.symbol))
            }
            // Humidity
            if let v = humidityStr {
                let unit = m.units.humidityUnit == .dew
                          ? m.units.temperatureUnit.symbol
                          : m.units.humidityUnit.symbol
                out.append(.make(kind: .humidity,
                                 title: "Humidity",
                                 value: v,
                                 unit: unit))
            }
            // Pressure
            if let v = pressureStr {
                out.append(.make(kind: .pressure,
                                 title: "Pressure",
                                 value: v,
                                 unit: m.units.pressureUnit.symbol))
            }

            // Air-quality extras -----------------------------------------
            if let co2 = record?.co2.flatMap   ({ m.co2String(for: $0) }) {
                out.append(.make(kind: .co2,  title: RuuviLocalization.unitCo2, value: co2, unit: nil))
            }
            if let pm25 = record?.pm2_5.flatMap({ m.pm25String(for: $0) }) {
                out.append(.make(kind: .pm25, title: RuuviLocalization.pm25,
                                 value: pm25,
                                 unit: RuuviLocalization.unitPm25))
            }
            if let pm10 = record?.pm10.flatMap({ m.pm10String(for: $0) }) {
                out.append(.make(kind: .pm10, title: RuuviLocalization.pm10,
                                 value: pm10,
                                 unit: RuuviLocalization.unitPm10))
            }
            if let nox = record?.nox.flatMap({ m.noxString(for: $0) }) {
                out.append(.make(kind: .nox,  title: RuuviLocalization.unitNox, value: nox))
            }
            if let voc = record?.voc.flatMap({ m.vocString(for: $0) }) {
                out.append(.make(kind: .voc,  title: RuuviLocalization.unitVoc, value: voc))
            }
            if let lum = record?.luminance.flatMap({ m.luminosityString(for: $0) }) {
                out.append(.make(kind: .luminosity,
                                 title: RuuviLocalization.unitLuminosity,
                                 value: lum))
            }
            if let snd = record?.dbaAvg.flatMap({ m.soundAvgString(for: $0) }) {
                out.append(.make(kind: .sound,
                                 title: RuuviLocalization.unitSound,
                                 value: snd))
            }
            return out
        }

        // ---- Firmware V5 or older --------------------------------------
        // Prominent = Temperature
        out.append(.make(kind: .temperature,
                         title: "Temp",
                         value: str(tempStr),
                         unit: m.units.temperatureUnit.symbol,
                         prominent: true))

        // Humidity
        if let v = humidityStr {
            let unit = m.units.humidityUnit == .dew
                      ? m.units.temperatureUnit.symbol
                      : m.units.humidityUnit.symbol
            out.append(.make(kind: .humidity,
                             title: "Humidity",
                             value: v,
                             unit: unit))
        }

        // Pressure
        if let v = pressureStr {
            out.append(.make(kind: .pressure,
                             title: "Pressure",
                             value: v,
                             unit: m.units.pressureUnit.symbol))
        }

        // Movement count
        if let move = record?.movementCounter {
            out.append(.make(kind: .movement,
                             title: RuuviLocalization.Cards.Movements.title,
                             value: "\(move)",
                             unit: nil))
        }
        return out
    }
}
