import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog13: [LocalizedStringContract] = [
        .init(
            key: "update", arguments: [],
            defaultValue: { RuuviLocalization.update },
            localized: { RuuviLocalization.update($0) }),
        .init(
            key: "update_air_check_timeout", arguments: [],
            defaultValue: { RuuviLocalization.updateAirCheckTimeout },
            localized: { RuuviLocalization.updateAirCheckTimeout($0) }),
        .init(
            key: "update_air_reboot_waiting", arguments: [],
            defaultValue: { RuuviLocalization.updateAirRebootWaiting },
            localized: { RuuviLocalization.updateAirRebootWaiting($0) }),
        .init(
            key: "update_air_version_mismatch", arguments: [],
            defaultValue: { RuuviLocalization.updateAirVersionMismatch },
            localized: { RuuviLocalization.updateAirVersionMismatch($0) }),
        .init(
            key: "update_now", arguments: [],
            defaultValue: { RuuviLocalization.updateNow },
            localized: { RuuviLocalization.updateNow($0) }),
        .init(
            key: "update_successful_air", arguments: [],
            defaultValue: { RuuviLocalization.updateSuccessfulAir },
            localized: { RuuviLocalization.updateSuccessfulAir($0) }),
        .init(
            key: "update_successful_tag", arguments: [],
            defaultValue: { RuuviLocalization.updateSuccessfulTag },
            localized: { RuuviLocalization.updateSuccessfulTag($0) }),
        .init(
            key: "uploading_progress", arguments: [Float(13.25)],
            defaultValue: { RuuviLocalization.uploadingProgress(Float(13.25)) },
            localized: { RuuviLocalization.uploadingProgress(Float(13.25), $0) }),
        .init(
            key: "use_bluetooth", arguments: [],
            defaultValue: { RuuviLocalization.useBluetooth },
            localized: { RuuviLocalization.useBluetooth($0) }),
        .init(
            key: "use_nfc", arguments: [],
            defaultValue: { RuuviLocalization.useNfc },
            localized: { RuuviLocalization.useNfc($0) }),
        .init(
            key: "use_without_account", arguments: [],
            defaultValue: { RuuviLocalization.useWithoutAccount },
            localized: { RuuviLocalization.useWithoutAccount($0) }),
        .init(
            key: "V", arguments: [],
            defaultValue: { RuuviLocalization.v },
            localized: { RuuviLocalization.v($0) }),
        .init(
            key: "verypoor", arguments: [],
            defaultValue: { RuuviLocalization.verypoor },
            localized: { RuuviLocalization.verypoor($0) }),
        .init(
            key: "view", arguments: [],
            defaultValue: { RuuviLocalization.view },
            localized: { RuuviLocalization.view($0) }),
        .init(
            key: "visible_measurements", arguments: [],
            defaultValue: { RuuviLocalization.visibleMeasurements },
            localized: { RuuviLocalization.visibleMeasurements($0) }),
        .init(
            key: "visible_measurements_active_alert_confirmation", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.visibleMeasurementsActiveAlertConfirmation("Sensor 1 🌡️") },
            localized: { RuuviLocalization.visibleMeasurementsActiveAlertConfirmation("Sensor 1 🌡️", $0) }),
        .init(
            key: "visible_measurements_change_use_default_confirmation", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.visibleMeasurementsChangeUseDefaultConfirmation("Sensor 1 🌡️") },
            localized: { RuuviLocalization.visibleMeasurementsChangeUseDefaultConfirmation("Sensor 1 🌡️", $0) }),
        .init(
            key: "visible_measurements_change_use_default_multiple_alerts_confirmation", arguments: ["Sensor 1 🌡️"],
            defaultValue: {
                RuuviLocalization.visibleMeasurementsChangeUseDefaultMultipleAlertsConfirmation("Sensor 1 🌡️")
            },
            localized: {
                RuuviLocalization.visibleMeasurementsChangeUseDefaultMultipleAlertsConfirmation("Sensor 1 🌡️", $0)
            }),
        .init(
            key: "visible_measurements_description", arguments: [],
            defaultValue: { RuuviLocalization.visibleMeasurementsDescription },
            localized: { RuuviLocalization.visibleMeasurementsDescription($0) }),
        .init(
            key: "visible_measurements_last_element_message", arguments: [],
            defaultValue: { RuuviLocalization.visibleMeasurementsLastElementMessage },
            localized: { RuuviLocalization.visibleMeasurementsLastElementMessage($0) }),
        .init(
            key: "visible_measurements_use_default", arguments: [],
            defaultValue: { RuuviLocalization.visibleMeasurementsUseDefault },
            localized: { RuuviLocalization.visibleMeasurementsUseDefault($0) }),
        .init(
            key: "voc", arguments: [],
            defaultValue: { RuuviLocalization.voc },
            localized: { RuuviLocalization.voc($0) }),
        .init(
            key: "voc_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.vocWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.vocWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "volatile_organic_compounds", arguments: [],
            defaultValue: { RuuviLocalization.volatileOrganicCompounds },
            localized: { RuuviLocalization.volatileOrganicCompounds($0) }),
        .init(
            key: "why_should_sign_in", arguments: [],
            defaultValue: { RuuviLocalization.whyShouldSignIn },
            localized: { RuuviLocalization.whyShouldSignIn($0) }),
        .init(
            key: "Yes", arguments: [],
            defaultValue: { RuuviLocalization.yes },
            localized: { RuuviLocalization.yes($0) }),
        .init(
            key: "ºC", arguments: [],
            defaultValue: { RuuviLocalization.ºC },
            localized: { RuuviLocalization.ºC($0) }),
        .init(
            key: "ºF", arguments: [],
            defaultValue: { RuuviLocalization.ºF },
            localized: { RuuviLocalization.ºF($0) }),
        .init(
            key: "About.AboutHelp.contents", arguments: [],
            defaultValue: { RuuviLocalization.About.AboutHelp.contents },
            localized: { RuuviLocalization.About.AboutHelp.contents($0) }),
        .init(
            key: "About.AboutHelp.header", arguments: [],
            defaultValue: { RuuviLocalization.About.AboutHelp.header },
            localized: { RuuviLocalization.About.AboutHelp.header($0) }),
        .init(
            key: "About.DatabaseSize.text", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.About.DatabaseSize.text("Sensor 1 🌡️") },
            localized: { RuuviLocalization.About.DatabaseSize.text("Sensor 1 🌡️", $0) }),
        .init(
            key: "About.MeasurementsCount.text", arguments: [1234],
            defaultValue: { RuuviLocalization.About.MeasurementsCount.text(1234) },
            localized: { RuuviLocalization.About.MeasurementsCount.text(1234, $0) }),
    ]
}
