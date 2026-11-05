import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog11: [LocalizedStringContract] = [
        .init(
            key: "s", arguments: [],
            defaultValue: { RuuviLocalization.s },
            localized: { RuuviLocalization.s($0) }),
        .init(
            key: "select_default_image", arguments: [],
            defaultValue: { RuuviLocalization.selectDefaultImage },
            localized: { RuuviLocalization.selectDefaultImage($0) }),
        .init(
            key: "select_from_gallery", arguments: [],
            defaultValue: { RuuviLocalization.selectFromGallery },
            localized: { RuuviLocalization.selectFromGallery($0) }),
        .init(
            key: "sensor_details", arguments: [],
            defaultValue: { RuuviLocalization.sensorDetails },
            localized: { RuuviLocalization.sensorDetails($0) }),
        .init(
            key: "sensor_not_found_error", arguments: [],
            defaultValue: { RuuviLocalization.sensorNotFoundError },
            localized: { RuuviLocalization.sensorNotFoundError($0) }),
        .init(
            key: "sensor_search_placeholder", arguments: [],
            defaultValue: { RuuviLocalization.sensorSearchPlaceholder },
            localized: { RuuviLocalization.sensorSearchPlaceholder($0) }),
        .init(
            key: "sensors_ownership_and_settings_stored_in_cloud", arguments: [],
            defaultValue: { RuuviLocalization.sensorsOwnershipAndSettingsStoredInCloud },
            localized: { RuuviLocalization.sensorsOwnershipAndSettingsStoredInCloud($0) }),
        .init(
            key: "settings_alert_limit_notification", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertLimitNotification },
            localized: { RuuviLocalization.settingsAlertLimitNotification($0) }),
        .init(
            key: "settings_alert_limit_notification_description", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertLimitNotificationDescription },
            localized: { RuuviLocalization.settingsAlertLimitNotificationDescription($0) }),
        .init(
            key: "settings_alert_notifications", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertNotifications },
            localized: { RuuviLocalization.settingsAlertNotifications($0) }),
        .init(
            key: "settings_alert_sound", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertSound },
            localized: { RuuviLocalization.settingsAlertSound($0) }),
        .init(
            key: "settings_alert_sound_default", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertSoundDefault },
            localized: { RuuviLocalization.settingsAlertSoundDefault($0) }),
        .init(
            key: "settings_alert_sound_description", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertSoundDescription },
            localized: { RuuviLocalization.settingsAlertSoundDescription($0) }),
        .init(
            key: "settings_alert_sound_ruuvi_speak", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertSoundRuuviSpeak },
            localized: { RuuviLocalization.settingsAlertSoundRuuviSpeak($0) }),
        .init(
            key: "settings_alerts_footer_description", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertsFooterDescription },
            localized: { RuuviLocalization.settingsAlertsFooterDescription($0) }),
        .init(
            key: "settings_alerts_footer_description_link_mask", arguments: [],
            defaultValue: { RuuviLocalization.settingsAlertsFooterDescriptionLinkMask },
            localized: { RuuviLocalization.settingsAlertsFooterDescriptionLinkMask($0) }),
        .init(
            key: "settings_appearance", arguments: [],
            defaultValue: { RuuviLocalization.settingsAppearance },
            localized: { RuuviLocalization.settingsAppearance($0) }),
        .init(
            key: "settings_email_alerts", arguments: [],
            defaultValue: { RuuviLocalization.settingsEmailAlerts },
            localized: { RuuviLocalization.settingsEmailAlerts($0) }),
        .init(
            key: "settings_email_alerts_description", arguments: [],
            defaultValue: { RuuviLocalization.settingsEmailAlertsDescription },
            localized: { RuuviLocalization.settingsEmailAlertsDescription($0) }),
        .init(
            key: "settings_push_alerts", arguments: [],
            defaultValue: { RuuviLocalization.settingsPushAlerts },
            localized: { RuuviLocalization.settingsPushAlerts($0) }),
        .init(
            key: "settings_push_alerts_description", arguments: [],
            defaultValue: { RuuviLocalization.settingsPushAlertsDescription },
            localized: { RuuviLocalization.settingsPushAlertsDescription($0) }),
        .init(
            key: "share_active_access_empty_value", arguments: [],
            defaultValue: { RuuviLocalization.shareActiveAccessEmptyValue },
            localized: { RuuviLocalization.shareActiveAccessEmptyValue($0) }),
        .init(
            key: "share_active_access_section_title", arguments: [],
            defaultValue: { RuuviLocalization.shareActiveAccessSectionTitle },
            localized: { RuuviLocalization.shareActiveAccessSectionTitle($0) }),
        .init(
            key: "share_pending", arguments: [],
            defaultValue: { RuuviLocalization.sharePending },
            localized: { RuuviLocalization.sharePending($0) }),
        .init(
            key: "share_pending_message", arguments: [],
            defaultValue: { RuuviLocalization.sharePendingMessage },
            localized: { RuuviLocalization.sharePendingMessage($0) }),
        .init(
            key: "share_pending_section_title", arguments: [],
            defaultValue: { RuuviLocalization.sharePendingSectionTitle },
            localized: { RuuviLocalization.sharePendingSectionTitle($0) }),
        .init(
            key: "share_sensor_shared_to_count_message", arguments: [1234, 1235, 1236, 1237],
            defaultValue: { RuuviLocalization.shareSensorSharedToCountMessage(1234, 1235, 1236, 1237) },
            localized: { RuuviLocalization.shareSensorSharedToCountMessage(1234, 1235, 1236, 1237, $0) }),
        .init(
            key: "shared_to_x", arguments: [1234, 1235],
            defaultValue: { RuuviLocalization.sharedToX(1234, 1235) },
            localized: { RuuviLocalization.sharedToX(1234, 1235, $0) }),
        .init(
            key: "show_less", arguments: [],
            defaultValue: { RuuviLocalization.showLess },
            localized: { RuuviLocalization.showLess($0) }),
        .init(
            key: "show_more", arguments: [],
            defaultValue: { RuuviLocalization.showMore },
            localized: { RuuviLocalization.showMore($0) }),
        .init(
            key: "sign_in_continue", arguments: [],
            defaultValue: { RuuviLocalization.signInContinue },
            localized: { RuuviLocalization.signInContinue($0) }),
        .init(
            key: "sign_in_or_create_free_account", arguments: [],
            defaultValue: { RuuviLocalization.signInOrCreateFreeAccount },
            localized: { RuuviLocalization.signInOrCreateFreeAccount($0) }),
    ]
}
