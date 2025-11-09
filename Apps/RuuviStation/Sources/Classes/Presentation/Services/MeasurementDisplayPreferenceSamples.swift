#if DEBUG

import Foundation
import RuuviOntology

enum MeasurementDisplayPreferenceSamples {
    enum SampleMode: String {
        case tagExtended = "TAG_EXTENDED"
        case airFocused = "AIR_FOCUSED"
    }

    static func applySamplePreferenceIfNeeded(to sensor: RuuviTagSensor) {
        guard let modeValue = ProcessInfo.processInfo.environment["MEASUREMENT_PROFILE_SAMPLE_MODE"],
              let mode = SampleMode(rawValue: modeValue.uppercased()) else {
            return
        }

        let format = RuuviDataFormat.dataFormat(from: sensor.version)
        let preference: RuuviTagDataService.MeasurementDisplayPreference

        switch mode {
        case .tagExtended:
            guard format != .e1 && format != .v6 else { return }
            preference = tagSamplePreference
        case .airFocused:
            guard format == .e1 || format == .v6 else { return }
            preference = airSamplePreference
        }

        RuuviTagDataService.setMeasurementDisplayPreference(preference, for: sensor.id)
    }

    private static let tagSamplePreference = RuuviTagDataService.MeasurementDisplayPreference(
        defaultDisplayOrder: false,
        displayOrderCodes: [
            "TEMPERATURE_C",
            "HUMIDITY_0",
            "PRESSURE_0",
            "PRESSURE_2",
            "ACCELERATION_GX",
            "ACCELERATION_GY",
            "ACCELERATION_GZ",
            "SIGNAL_DBM",
            "BATTERY_VOLT",
            "TEMPERATURE_K",
        ]
    )

    private static let airSamplePreference = RuuviTagDataService.MeasurementDisplayPreference(
        defaultDisplayOrder: false,
        displayOrderCodes: [
            "AQI_INDEX",
            "TEMPERATURE_K",
            "CO2_PPM",
            "PM25_MGM3",
            "PM40_MGM3",
            "PM100_MGM3",
            "SIGNAL_DBM",
        ]
    )
}

#endif
