import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog4: [LocalizedStringContract] = [
        .init(
            key: "carbon_dioxide", arguments: [],
            defaultValue: { RuuviLocalization.carbonDioxide },
            localized: { RuuviLocalization.carbonDioxide($0) }),
        .init(
            key: "card_action", arguments: [],
            defaultValue: { RuuviLocalization.cardAction },
            localized: { RuuviLocalization.cardAction($0) }),
        .init(
            key: "card_type", arguments: [],
            defaultValue: { RuuviLocalization.cardType },
            localized: { RuuviLocalization.cardType($0) }),
        .init(
            key: "change_background", arguments: [],
            defaultValue: { RuuviLocalization.changeBackground },
            localized: { RuuviLocalization.changeBackground($0) }),
        .init(
            key: "change_background_message", arguments: [],
            defaultValue: { RuuviLocalization.changeBackgroundMessage },
            localized: { RuuviLocalization.changeBackgroundMessage($0) }),
        .init(
            key: "changelog", arguments: [],
            defaultValue: { RuuviLocalization.changelog },
            localized: { RuuviLocalization.changelog($0) }),
        .init(
            key: "changelog_ios_url", arguments: [],
            defaultValue: { RuuviLocalization.changelogIosUrl },
            localized: { RuuviLocalization.changelogIosUrl($0) }),
        .init(
            key: "chart_min_max_avg", arguments: ["Sensor 1 🌡️", "Sensor 2 🌡️", "Sensor 3 🌡️"],
            defaultValue: { RuuviLocalization.chartMinMaxAvg("Sensor 1 🌡️", "Sensor 2 🌡️", "Sensor 3 🌡️") },
            localized: { RuuviLocalization.chartMinMaxAvg("Sensor 1 🌡️", "Sensor 2 🌡️", "Sensor 3 🌡️", $0) }),
        .init(
            key: "chart_stat_hide", arguments: [],
            defaultValue: { RuuviLocalization.chartStatHide },
            localized: { RuuviLocalization.chartStatHide($0) }),
        .init(
            key: "chart_stat_max", arguments: [],
            defaultValue: { RuuviLocalization.chartStatMax },
            localized: { RuuviLocalization.chartStatMax($0) }),
        .init(
            key: "chart_stat_min", arguments: [],
            defaultValue: { RuuviLocalization.chartStatMin },
            localized: { RuuviLocalization.chartStatMin($0) }),
        .init(
            key: "chart_stat_show", arguments: [],
            defaultValue: { RuuviLocalization.chartStatShow },
            localized: { RuuviLocalization.chartStatShow($0) }),
        .init(
            key: "claim_sensor_ownership", arguments: [],
            defaultValue: { RuuviLocalization.claimSensorOwnership },
            localized: { RuuviLocalization.claimSensorOwnership($0) }),
        .init(
            key: "claim_warning", arguments: [],
            defaultValue: { RuuviLocalization.claimWarning },
            localized: { RuuviLocalization.claimWarning($0) }),
        .init(
            key: "claim_wrong_sensor_scanned", arguments: [],
            defaultValue: { RuuviLocalization.claimWrongSensorScanned },
            localized: { RuuviLocalization.claimWrongSensorScanned($0) }),
        .init(
            key: "clear_local_history", arguments: [],
            defaultValue: { RuuviLocalization.clearLocalHistory },
            localized: { RuuviLocalization.clearLocalHistory($0) }),
        .init(
            key: "clear_local_history_description", arguments: [],
            defaultValue: { RuuviLocalization.clearLocalHistoryDescription },
            localized: { RuuviLocalization.clearLocalHistoryDescription($0) }),
        .init(
            key: "clear_view", arguments: [],
            defaultValue: { RuuviLocalization.clearView },
            localized: { RuuviLocalization.clearView($0) }),
        .init(
            key: "Close", arguments: [],
            defaultValue: { RuuviLocalization.close },
            localized: { RuuviLocalization.close($0) }),
        .init(
            key: "cloud_stored_alerts", arguments: [],
            defaultValue: { RuuviLocalization.cloudStoredAlerts },
            localized: { RuuviLocalization.cloudStoredAlerts($0) }),
        .init(
            key: "cloud_stored_backgrounds", arguments: [],
            defaultValue: { RuuviLocalization.cloudStoredBackgrounds },
            localized: { RuuviLocalization.cloudStoredBackgrounds($0) }),
        .init(
            key: "cloud_stored_calibration", arguments: [],
            defaultValue: { RuuviLocalization.cloudStoredCalibration },
            localized: { RuuviLocalization.cloudStoredCalibration($0) }),
        .init(
            key: "cloud_stored_names", arguments: [],
            defaultValue: { RuuviLocalization.cloudStoredNames },
            localized: { RuuviLocalization.cloudStoredNames($0) }),
        .init(
            key: "cloud_stored_ownerships", arguments: [],
            defaultValue: { RuuviLocalization.cloudStoredOwnerships },
            localized: { RuuviLocalization.cloudStoredOwnerships($0) }),
        .init(
            key: "cloud_stored_sharing", arguments: [],
            defaultValue: { RuuviLocalization.cloudStoredSharing },
            localized: { RuuviLocalization.cloudStoredSharing($0) }),
        .init(
            key: "co2", arguments: [],
            defaultValue: { RuuviLocalization.co2 },
            localized: { RuuviLocalization.co2($0) }),
        .init(
            key: "co2_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.co2WithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.co2WithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "communication_channels", arguments: [],
            defaultValue: { RuuviLocalization.communicationChannels },
            localized: { RuuviLocalization.communicationChannels($0) }),
        .init(
            key: "communication_channels_description", arguments: [],
            defaultValue: { RuuviLocalization.communicationChannelsDescription },
            localized: { RuuviLocalization.communicationChannelsDescription($0) }),
        .init(
            key: "Confirm", arguments: [],
            defaultValue: { RuuviLocalization.confirm },
            localized: { RuuviLocalization.confirm($0) }),
        .init(
            key: "Copy", arguments: [],
            defaultValue: { RuuviLocalization.copy },
            localized: { RuuviLocalization.copy($0) }),
        .init(
            key: "copy_mac_address", arguments: [],
            defaultValue: { RuuviLocalization.copyMacAddress },
            localized: { RuuviLocalization.copyMacAddress($0) }),
    ]
}
