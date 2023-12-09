// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum RuuviLocalization {
  /// Operation failed.
  public static let activityFailedGeneric = RuuviLocalization.tr("Localizable", "activity_failed_generic", fallback: "Operation failed.")
  /// Please wait...
  public static let activityOngoingGeneric = RuuviLocalization.tr("Localizable", "activity_ongoing_generic", fallback: "Please wait...")
  /// Couldn't save changes to cloud.
  public static let activitySavingFail = RuuviLocalization.tr("Localizable", "activity_saving_fail", fallback: "Couldn't save changes to cloud.")
  /// Saved successfully.
  public static let activitySavingSuccess = RuuviLocalization.tr("Localizable", "activity_saving_success", fallback: "Saved successfully.")
  /// Saving to cloud...please wait.
  public static let activitySavingToCloud = RuuviLocalization.tr("Localizable", "activity_saving_to_cloud", fallback: "Saving to cloud...please wait.")
  /// Operation successful.
  public static let activitySuccessGeneric = RuuviLocalization.tr("Localizable", "activity_success_generic", fallback: "Operation successful.")
  /// Add a Sensor
  public static let addASensor = RuuviLocalization.tr("Localizable", "add_a_sensor", fallback: "Add a Sensor")
  /// Add Sensor
  public static let addSensor = RuuviLocalization.tr("Localizable", "add_sensor", fallback: "Add Sensor")
  /// This page shows nearby Ruuvi sensors not yet added to the app. Tap a sensor to add it.
  public static let addSensorDescription = RuuviLocalization.tr("Localizable", "add_sensor_description", fallback: "This page shows nearby Ruuvi sensors not yet added to the app. Tap a sensor to add it.")
  /// This sensor cannot be added with NFC due to old firmware. Please add the sensor with Bluetooth and update firmware.
  public static let addSensorNfcDf3Error = RuuviLocalization.tr("Localizable", "add_sensor_nfc_df3_error", fallback: "This sensor cannot be added with NFC due to old firmware. Please add the sensor with Bluetooth and update firmware.")
  /// Alternatively, you can add a sensor using NFC by selecting Add with NFC and touching it with your phone.
  public static let addSensorViaNfc = RuuviLocalization.tr("Localizable", "add_sensor_via_nfc", fallback: "Alternatively, you can add a sensor using NFC by selecting Add with NFC and touching it with your phone.")
  /// Add with NFC
  public static let addWithNfc = RuuviLocalization.tr("Localizable", "add_with_nfc", fallback: "Add with NFC")
  /// ago
  public static let ago = RuuviLocalization.tr("Localizable", "ago", fallback: "ago")
  /// Alert if sensor data hasn't been updated to the cloud for longer than %d minutes.
  public static func alertCloudConnectionDescription(_ p1: Int) -> String {
    return RuuviLocalization.tr("Localizable", "alert_cloud_connection_description", p1, fallback: "Alert if sensor data hasn't been updated to the cloud for longer than %d minutes.")
  }
  /// Enter the desired delay to be used in minutes before alert is triggered. Minimum value is 2 minutes.
  public static let alertCloudConnectionDialogDescription = RuuviLocalization.tr("Localizable", "alert_cloud_connection_dialog_description", fallback: "Enter the desired delay to be used in minutes before alert is triggered. Minimum value is 2 minutes.")
  /// Set cloud connection alert
  public static let alertCloudConnectionDialogTitle = RuuviLocalization.tr("Localizable", "alert_cloud_connection_dialog_title", fallback: "Set cloud connection alert")
  /// Cloud Connection
  public static let alertCloudConnectionTitle = RuuviLocalization.tr("Localizable", "alert_cloud_connection_title", fallback: "Cloud Connection")
  /// Air Humidity is above %@
  public static func alertNotificationHumidityHighThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_humidity_high_threshold", String(describing: p1), fallback: "Air Humidity is above %@")
  }
  /// Air Humidity is below %@
  public static func alertNotificationHumidityLowThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_humidity_low_threshold", String(describing: p1), fallback: "Air Humidity is below %@")
  }
  /// Air Pressure is above %@
  public static func alertNotificationPressureHighThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_pressure_high_threshold", String(describing: p1), fallback: "Air Pressure is above %@")
  }
  /// Air Pressure is below %@
  public static func alertNotificationPressureLowThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_pressure_low_threshold", String(describing: p1), fallback: "Air Pressure is below %@")
  }
  /// Signal strength is above %@
  public static func alertNotificationRssiHighThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_rssi_high_threshold", String(describing: p1), fallback: "Signal strength is above %@")
  }
  /// Signal strength is below %@
  public static func alertNotificationRssiLowThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_rssi_low_threshold", String(describing: p1), fallback: "Signal strength is below %@")
  }
  /// Temperature is above %@
  public static func alertNotificationTemperatureHighThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_temperature_high_threshold", String(describing: p1), fallback: "Temperature is above %@")
  }
  /// Temperature is below %@
  public static func alertNotificationTemperatureLowThreshold(_ p1: Any) -> String {
    return RuuviLocalization.tr("Localizable", "alert_notification_temperature_low_threshold", String(describing: p1), fallback: "Temperature is below %@")
  }
  /// All
  public static let all = RuuviLocalization.tr("Localizable", "all", fallback: "All")
  /// App Theme
  public static let appTheme = RuuviLocalization.tr("Localizable", "app_theme", fallback: "App Theme")
  /// Read more about Ruuvi account benefits or sign in later
  public static let benefitsSignIn = RuuviLocalization.tr("Localizable", "benefits_sign_in", fallback: "Read more about Ruuvi account benefits or sign in later")
  /// Bluetooth download
  public static let bluetoothDownload = RuuviLocalization.tr("Localizable", "bluetooth_download", fallback: "Bluetooth download")
  /// Local sensor data can be downloaded, when you're within its Bluetooth range.
  public static let bluetoothDownloadDescription = RuuviLocalization.tr("Localizable", "bluetooth_download_description", fallback: "Local sensor data can be downloaded, when you're within its Bluetooth range.")
  /// Cancel
  public static let cancel = RuuviLocalization.tr("Localizable", "Cancel", fallback: "Cancel")
  /// Card action
  public static let cardAction = RuuviLocalization.tr("Localizable", "card_action", fallback: "Card action")
  /// Card type
  public static let cardType = RuuviLocalization.tr("Localizable", "card_type", fallback: "Card type")
  /// Change background
  public static let changeBackground = RuuviLocalization.tr("Localizable", "change_background", fallback: "Change background")
  /// Change background image
  public static let changeBackgroundImage = RuuviLocalization.tr("Localizable", "change_background_image", fallback: "Change background image")
  /// Select background image. If you're not signed in, you'll lose the image in case of app reinstall.
  public static let changeBackgroundMessage = RuuviLocalization.tr("Localizable", "change_background_message", fallback: "Select background image. If you're not signed in, you'll lose the image in case of app reinstall.")
  /// (changelog)
  public static let changelog = RuuviLocalization.tr("Localizable", "changelog", fallback: "(changelog)")
  /// https://f.ruuvi.com/t/3192
  public static let changelogIosUrl = RuuviLocalization.tr("Localizable", "changelog_ios_url", fallback: "https://f.ruuvi.com/t/3192")
  /// Average
  public static let chartStatAvg = RuuviLocalization.tr("Localizable", "chart_stat_avg", fallback: "Average")
  /// Hide min/max/avg
  public static let chartStatHide = RuuviLocalization.tr("Localizable", "chart_stat_hide", fallback: "Hide min/max/avg")
  /// Max
  public static let chartStatMax = RuuviLocalization.tr("Localizable", "chart_stat_max", fallback: "Max")
  /// Min
  public static let chartStatMin = RuuviLocalization.tr("Localizable", "chart_stat_min", fallback: "Min")
  /// Show min/max/avg
  public static let chartStatShow = RuuviLocalization.tr("Localizable", "chart_stat_show", fallback: "Show min/max/avg")
  /// Checking claim state
  public static let checkClaimState = RuuviLocalization.tr("Localizable", "check_claim_state", fallback: "Checking claim state")
  /// Claiming in progress
  public static let claimInProgress = RuuviLocalization.tr("Localizable", "claim_in_progress", fallback: "Claiming in progress")
  /// Claim sensor ownership
  public static let claimSensorOwnership = RuuviLocalization.tr("Localizable", "claim_sensor_ownership", fallback: "Claim sensor ownership")
  /// Secure the ownership information of your sensors by claiming their ownerships in the app.
  public static let claimWarning = RuuviLocalization.tr("Localizable", "claim_warning", fallback: "Secure the ownership information of your sensors by claiming their ownerships in the app.")
  /// You are scanning different RuuviTag
  public static let claimWrongSensorScanned = RuuviLocalization.tr("Localizable", "claim_wrong_sensor_scanned", fallback: "You are scanning different RuuviTag")
  /// Clear local history
  public static let clearLocalHistory = RuuviLocalization.tr("Localizable", "clear_local_history", fallback: "Clear local history")
  /// Do you want to clear locally stored history data from the app? This won't clear internally stored history from the sensor or history data stored on the Ruuvi Cloud service.
  public static let clearLocalHistoryDescription = RuuviLocalization.tr("Localizable", "clear_local_history_description", fallback: "Do you want to clear locally stored history data from the app? This won't clear internally stored history from the sensor or history data stored on the Ruuvi Cloud service.")
  /// Clear history view
  public static let clearView = RuuviLocalization.tr("Localizable", "clear_view", fallback: "Clear history view")
  /// Close
  public static let close = RuuviLocalization.tr("Localizable", "Close", fallback: "Close")
  /// ● Background images
  public static let cloudStoredAlerts = RuuviLocalization.tr("Localizable", "cloud_stored_alerts", fallback: "● Background images")
  /// ● Alert settings
  public static let cloudStoredBackgrounds = RuuviLocalization.tr("Localizable", "cloud_stored_backgrounds", fallback: "● Alert settings")
  /// ● Calibration settings
  public static let cloudStoredCalibration = RuuviLocalization.tr("Localizable", "cloud_stored_calibration", fallback: "● Calibration settings")
  /// ● Custom names
  public static let cloudStoredNames = RuuviLocalization.tr("Localizable", "cloud_stored_names", fallback: "● Custom names")
  /// ● Sensor ownerships
  public static let cloudStoredOwnerships = RuuviLocalization.tr("Localizable", "cloud_stored_ownerships", fallback: "● Sensor ownerships")
  /// ● App settings
  public static let cloudStoredSharing = RuuviLocalization.tr("Localizable", "cloud_stored_sharing", fallback: "● App settings")
  /// Confirm
  public static let confirm = RuuviLocalization.tr("Localizable", "Confirm", fallback: "Confirm")
  /// Copy
  public static let copy = RuuviLocalization.tr("Localizable", "Copy", fallback: "Copy")
  /// Copy MAC Address
  public static let copyMacAddress = RuuviLocalization.tr("Localizable", "copy_mac_address", fallback: "Copy MAC Address")
  /// Copy Unique ID
  public static let copyUniqueId = RuuviLocalization.tr("Localizable", "copy_unique_id", fallback: "Copy Unique ID")
  /// Dark theme
  public static let darkTheme = RuuviLocalization.tr("Localizable", "dark_theme", fallback: "Dark theme")
  /// Seems that you don't have any Ruuvi sensors added yet.
  public static let dashboardNoSensorsMessage = RuuviLocalization.tr("Localizable", "dashboard_no_sensors_message", fallback: "Seems that you don't have any Ruuvi sensors added yet.")
  /// You are not signed in.
  /// 
  /// If you have an account and have already added Ruuvi sensors to it, they will automatically synchronise with Ruuvi Station mobile app when you sign in.
  public static let dashboardNoSensorsMessageSignedOut = RuuviLocalization.tr("Localizable", "dashboard_no_sensors_message_signed_out", fallback: "You are not signed in.\n\nIf you have an account and have already added Ruuvi sensors to it, they will automatically synchronise with Ruuvi Station mobile app when you sign in.")
  /// 1 day
  public static let day1 = RuuviLocalization.tr("Localizable", "day_1", fallback: "1 day")
  /// 10 days
  public static let day10 = RuuviLocalization.tr("Localizable", "day_10", fallback: "10 days")
  /// 2 days
  public static let day2 = RuuviLocalization.tr("Localizable", "day_2", fallback: "2 days")
  /// 3 days
  public static let day3 = RuuviLocalization.tr("Localizable", "day_3", fallback: "3 days")
  /// 4 days
  public static let day4 = RuuviLocalization.tr("Localizable", "day_4", fallback: "4 days")
  /// 5 days
  public static let day5 = RuuviLocalization.tr("Localizable", "day_5", fallback: "5 days")
  /// 6 days
  public static let day6 = RuuviLocalization.tr("Localizable", "day_6", fallback: "6 days")
  /// 7 days
  public static let day7 = RuuviLocalization.tr("Localizable", "day_7", fallback: "7 days")
  /// 8 days
  public static let day8 = RuuviLocalization.tr("Localizable", "day_8", fallback: "8 days")
  /// 9 days
  public static let day9 = RuuviLocalization.tr("Localizable", "day_9", fallback: "9 days")
  /// %0.f days
  public static let dayX = RuuviLocalization.tr("Localizable", "day_x", fallback: "%0.f days")
  /// dBm
  public static let dBm = RuuviLocalization.tr("Localizable", "dBm", fallback: "dBm")
  /// Are you sure?
  public static let dialogAreYouSure = RuuviLocalization.tr("Localizable", "dialog_are_you_sure", fallback: "Are you sure?")
  /// This operation cannot be undone.
  public static let dialogOperationUndone = RuuviLocalization.tr("Localizable", "dialog_operation_undone", fallback: "This operation cannot be undone.")
  /// Don't show this again
  public static let doNotShowAgain = RuuviLocalization.tr("Localizable", "do_not_show_again", fallback: "Don't show this again")
  /// Do you own this sensor?
  public static let doYouOwnSensor = RuuviLocalization.tr("Localizable", "do_you_own_sensor", fallback: "Do you own this sensor?")
  /// Done
  public static let done = RuuviLocalization.tr("Localizable", "Done", fallback: "Done")
  /// Download
  public static let download = RuuviLocalization.tr("Localizable", "download", fallback: "Download")
  /// No data available 
  /// in the selected history window.
  public static let emptyChartMessage = RuuviLocalization.tr("Localizable", "empty_chart_message", fallback: "No data available \nin the selected history window.")
  /// Enter Code
  public static let enterCode = RuuviLocalization.tr("Localizable", "enter_code", fallback: "Enter Code")
  /// You can export a sensor's history from its history graph page. Tap the three dots menu icon in the top right corner, and then select "Export history (csv)".
  public static let exportCsvFeatureLocation = RuuviLocalization.tr("Localizable", "export_csv_feature_location", fallback: "You can export a sensor's history from its history graph page. Tap the three dots menu icon in the top right corner, and then select \"Export history (csv)\".")
  /// Export history (csv)
  public static let exportHistory = RuuviLocalization.tr("Localizable", "export_history", fallback: "Export history (csv)")
  /// Firmware Version:
  public static let firmwareVersion = RuuviLocalization.tr("Localizable", "firmware_version", fallback: "Firmware Version:")
  /// System theme
  public static let followSystemTheme = RuuviLocalization.tr("Localizable", "follow_system_theme", fallback: "System theme")
  /// Force Claim
  public static let forceClaim = RuuviLocalization.tr("Localizable", "force_claim", fallback: "Force Claim")
  /// Force Claim Sensor
  public static let forceClaimSensor = RuuviLocalization.tr("Localizable", "force_claim_sensor", fallback: "Force Claim Sensor")
  /// This sensor has been claimed by another user. You can force the ownership to your account if you have physical access to this sensor. Each Ruuvi sensor can have only one owner.
  public static let forceClaimSensorDescription1 = RuuviLocalization.tr("Localizable", "force_claim_sensor_description1", fallback: "This sensor has been claimed by another user. You can force the ownership to your account if you have physical access to this sensor. Each Ruuvi sensor can have only one owner.")
  /// Force Claim is done by using Near-Field Communication (NFC). Make sure NFC is enabled on your mobile device.
  /// 
  /// 	1. Touch your Ruuvi sensor with your mobile device to start the claiming process.
  /// 
  /// 	2. When successfully claimed, you will be sent back to Sensor Settings.
  /// 
  /// If claiming was unsuccessful or NFC is not available on your device:
  /// 
  /// 	1. Open the cover of your Ruuvi sensor.
  /// 
  /// 	2. Locate the round black button (or button "B" in case your sensor has 2 buttons) on the white circuit board and press it briefly, then tap on Use BT button to start the claiming process.
  /// 
  /// 	3. When successfully claimed you will be sent back to Sensor Settings.
  public static let forceClaimSensorDescription2 = RuuviLocalization.tr("Localizable", "force_claim_sensor_description2", fallback: "Force Claim is done by using Near-Field Communication (NFC). Make sure NFC is enabled on your mobile device.\n\n\t1. Touch your Ruuvi sensor with your mobile device to start the claiming process.\n\n\t2. When successfully claimed, you will be sent back to Sensor Settings.\n\nIf claiming was unsuccessful or NFC is not available on your device:\n\n\t1. Open the cover of your Ruuvi sensor.\n\n\t2. Locate the round black button (or button \"B\" in case your sensor has 2 buttons) on the white circuit board and press it briefly, then tap on Use BT button to start the claiming process.\n\n\t3. When successfully claimed you will be sent back to Sensor Settings.")
  /// Full image view
  public static let fullImageView = RuuviLocalization.tr("Localizable", "full_image_view", fallback: "Full image view")
  /// g
  public static let g = RuuviLocalization.tr("Localizable", "g", fallback: "g")
  /// g/m³
  public static let gm³ = RuuviLocalization.tr("Localizable", "g/m³", fallback: "g/m³")
  /// Ruuvi Station downloads the internal history of the sensor for the last 10 days if the measurement history is available.
  /// 
  /// The history is downloaded using a Bluetooth connection. Make sure you are near the sensor.
  public static let gattSyncDescription = RuuviLocalization.tr("Localizable", "gatt_sync_description", fallback: "Ruuvi Station downloads the internal history of the sensor for the last 10 days if the measurement history is available.\n\nThe history is downloaded using a Bluetooth connection. Make sure you are near the sensor.")
  /// Go to sensor card
  public static let goToSensor = RuuviLocalization.tr("Localizable", "go_to_sensor", fallback: "Go to sensor card")
  /// h
  public static let h = RuuviLocalization.tr("Localizable", "h", fallback: "h")
  /// History view
  public static let historyView = RuuviLocalization.tr("Localizable", "history_view", fallback: "History view")
  /// Hour
  public static let hour = RuuviLocalization.tr("Localizable", "hour", fallback: "Hour")
  /// Hours
  public static let hours = RuuviLocalization.tr("Localizable", "hours", fallback: "Hours")
  /// hPa
  public static let hPa = RuuviLocalization.tr("Localizable", "hPa", fallback: "hPa")
  /// Image cards
  public static let imageCards = RuuviLocalization.tr("Localizable", "image_cards", fallback: "Image cards")
  /// Internet connection problem
  public static let internetConnectionProblem = RuuviLocalization.tr("Localizable", "internet_connection_problem", fallback: "Internet connection problem")
  /// Let's Sign In
  public static let letsDoIt = RuuviLocalization.tr("Localizable", "lets_do_it", fallback: "Let's Sign In")
  /// Light theme
  public static let lightTheme = RuuviLocalization.tr("Localizable", "light_theme", fallback: "Light theme")
  /// Ruuvi Station mobile app supports maximum 10 days of history. Ruuvi Cloud subscribers are able to view up to 2 years of historical data using web app at ruuvi.com/station (requires Ruuvi Gateway router).
  public static let longerHistoryMessage = RuuviLocalization.tr("Localizable", "longer_history_message", fallback: "Ruuvi Station mobile app supports maximum 10 days of history. Ruuvi Cloud subscribers are able to view up to 2 years of historical data using web app at ruuvi.com/station (requires Ruuvi Gateway router).")
  /// Longer history
  public static let longerHistoryTitle = RuuviLocalization.tr("Localizable", "longer_history_title", fallback: "Longer history")
  /// Low battery
  public static let lowBattery = RuuviLocalization.tr("Localizable", "low_battery", fallback: "Low battery")
  /// Mac Address:
  public static let macAddress = RuuviLocalization.tr("Localizable", "mac_address", fallback: "Mac Address:")
  /// min
  public static let min = RuuviLocalization.tr("Localizable", "min", fallback: "min")
  /// Minutes
  public static let minutes = RuuviLocalization.tr("Localizable", "minutes", fallback: "Minutes")
  /// More...
  public static let more = RuuviLocalization.tr("Localizable", "more", fallback: "More...")
  /// -
  public static let na = RuuviLocalization.tr("Localizable", "N/A", fallback: "-")
  /// Name:
  public static let name = RuuviLocalization.tr("Localizable", "name", fallback: "Name:")
  /// Only sensors within range of your Ruuvi Gateway can be shared.
  public static let networkSharingDisabled = RuuviLocalization.tr("Localizable", "network_sharing_disabled", fallback: "Only sensors within range of your Ruuvi Gateway can be shared.")
  /// No
  public static let no = RuuviLocalization.tr("Localizable", "No", fallback: "No")
  /// A free account will be created for this email if you don't already have one. Only email address is required. We keep your information safe.
  public static let noPasswordNeeded = RuuviLocalization.tr("Localizable", "no_password_needed", fallback: "A free account will be created for this email if you don't already have one. Only email address is required. We keep your information safe.")
  /// Note!
  public static let note = RuuviLocalization.tr("Localizable", "note", fallback: "Note!")
  /// Off
  public static let off = RuuviLocalization.tr("Localizable", "Off", fallback: "Off")
  /// OK
  public static let ok = RuuviLocalization.tr("Localizable", "OK", fallback: "OK")
  /// On
  public static let on = RuuviLocalization.tr("Localizable", "On", fallback: "On")
  /// Bring your favorite sensors to your Home Screen and Lock Screen as
  public static let onboardingAccessWidgets = RuuviLocalization.tr("Localizable", "onboarding_access_widgets", fallback: "Bring your favorite sensors to your Home Screen and Lock Screen as")
  /// Alerts
  public static let onboardingAlerts = RuuviLocalization.tr("Localizable", "onboarding_alerts", fallback: "Alerts")
  /// Next
  public static let onboardingContinue = RuuviLocalization.tr("Localizable", "onboarding_continue", fallback: "Next")
  /// Dashboard
  public static let onboardingDashboard = RuuviLocalization.tr("Localizable", "onboarding_dashboard", fallback: "Dashboard")
  /// Explore your measurement
  public static let onboardingExploreDetailed = RuuviLocalization.tr("Localizable", "onboarding_explore_detailed", fallback: "Explore your measurement")
  /// View all sensors at a glance on your
  public static let onboardingFollowMeasurement = RuuviLocalization.tr("Localizable", "onboarding_follow_measurement", fallback: "View all sensors at a glance on your")
  /// A Ruuvi Gateway router is required.
  public static let onboardingGatewayRequired = RuuviLocalization.tr("Localizable", "onboarding_gateway_required", fallback: "A Ruuvi Gateway router is required.")
  /// Ruuvi experience is better when you're signed in. Do it now or continue without cloud features.
  public static let onboardingGoToSignIn = RuuviLocalization.tr("Localizable", "onboarding_go_to_sign_in", fallback: "Ruuvi experience is better when you're signed in. Do it now or continue without cloud features.")
  /// Let's start measuring!
  public static let onboardingGoToSignInAlreadySignedIn = RuuviLocalization.tr("Localizable", "onboarding_go_to_sign_in_already_signed_in", fallback: "Let's start measuring!")
  /// Widgets
  public static let onboardingHandyWidgets = RuuviLocalization.tr("Localizable", "onboarding_handy_widgets", fallback: "Widgets")
  /// History
  public static let onboardingHistory = RuuviLocalization.tr("Localizable", "onboarding_history", fallback: "History")
  /// Measure Your World
  public static let onboardingMeasureYourWorld = RuuviLocalization.tr("Localizable", "onboarding_measure_your_world", fallback: "Measure Your World")
  /// Personalise
  public static let onboardingPersonalise = RuuviLocalization.tr("Localizable", "onboarding_personalise", fallback: "Personalise")
  /// Read Your Ruuvi Sensors
  public static let onboardingReadSensorsData = RuuviLocalization.tr("Localizable", "onboarding_read_sensors_data", fallback: "Read Your Ruuvi Sensors")
  /// Set and customise your
  public static let onboardingSetCustom = RuuviLocalization.tr("Localizable", "onboarding_set_custom", fallback: "Set and customise your")
  /// to measure together with your friends and family.
  public static let onboardingShareYourSensors = RuuviLocalization.tr("Localizable", "onboarding_share_your_sensors", fallback: "to measure together with your friends and family.")
  /// Share Sensors
  public static let onboardingShareesCanUse = RuuviLocalization.tr("Localizable", "onboarding_sharees_can_use", fallback: "Share Sensors")
  /// Skip
  public static let onboardingSkip = RuuviLocalization.tr("Localizable", "onboarding_skip", fallback: "Skip")
  /// Ruuvi Web App
  public static let onboardingStationWeb = RuuviLocalization.tr("Localizable", "onboarding_station_web", fallback: "Ruuvi Web App")
  /// Swipe to continue →
  public static let onboardingSwipeToContinue = RuuviLocalization.tr("Localizable", "onboarding_swipe_to_continue", fallback: "Swipe to continue →")
  /// Almost there!
  public static let onboardingThatsIt = RuuviLocalization.tr("Localizable", "onboarding_thats_it", fallback: "Almost there!")
  /// Let's get started!
  public static let onboardingThatsItAlreadySignedIn = RuuviLocalization.tr("Localizable", "onboarding_thats_it_already_signed_in", fallback: "Let's get started!")
  /// using Bluetooth or Ruuvi Cloud
  public static let onboardingViaBluetoothOrCloud = RuuviLocalization.tr("Localizable", "onboarding_via_bluetooth_or_cloud", fallback: "using Bluetooth or Ruuvi Cloud")
  /// Large dashboard, multi-year history, email alerts and more on
  public static let onboardingWebPros = RuuviLocalization.tr("Localizable", "onboarding_web_pros", fallback: "Large dashboard, multi-year history, email alerts and more on")
  /// Let's get to know your Ruuvi Station app.
  public static let onboardingWithRuuviSensors = RuuviLocalization.tr("Localizable", "onboarding_with_ruuvi_sensors", fallback: "Let's get to know your Ruuvi Station app.")
  /// your app with custom names and backgrounds.
  public static let onboardingYourSensors = RuuviLocalization.tr("Localizable", "onboarding_your_sensors", fallback: "your app with custom names and backgrounds.")
  /// Open history view
  public static let openHistoryView = RuuviLocalization.tr("Localizable", "open_history_view", fallback: "Open history view")
  /// Open sensor view
  public static let openSensorView = RuuviLocalization.tr("Localizable", "open_sensor_view", fallback: "Open sensor view")
  /// Owner's Ruuvi Plan
  public static let ownersPlan = RuuviLocalization.tr("Localizable", "owners_plan", fallback: "Owner's Ruuvi Plan")
  /// Reading Bluetooth: %0.f
  public static let readingHistoryX = RuuviLocalization.tr("Localizable", "reading_history_x", fallback: "Reading Bluetooth: %0.f")
  /// Remove
  public static let remove = RuuviLocalization.tr("Localizable", "Remove", fallback: "Remove")
  /// By removing the sensor, your sensor ownership status will be revoked and sensor settings, such as name, background image, calibration settings and alert settings will be removed. After removal, someone else can claim ownership of the sensor. Each Ruuvi sensor can have only one owner.
  public static let removeClaimedSensorDescription = RuuviLocalization.tr("Localizable", "remove_claimed_sensor_description", fallback: "By removing the sensor, your sensor ownership status will be revoked and sensor settings, such as name, background image, calibration settings and alert settings will be removed. After removal, someone else can claim ownership of the sensor. Each Ruuvi sensor can have only one owner.")
  /// I also want to remove sensor history data from Ruuvi Cloud.
  public static let removeCloudHistoryDescription = RuuviLocalization.tr("Localizable", "remove_cloud_history_description", fallback: "I also want to remove sensor history data from Ruuvi Cloud.")
  /// Remove cloud history
  public static let removeCloudHistoryTitle = RuuviLocalization.tr("Localizable", "remove_cloud_history_title", fallback: "Remove cloud history")
  /// If you choose to remove this sensor, it will result in the deletion of your locally stored measurement history, along with the removal of any related sensor settings like name, background image, calibration, and alert configurations.
  /// 
  /// You can add this sensor later again, if needed.
  public static let removeLocalSensorDescription = RuuviLocalization.tr("Localizable", "remove_local_sensor_description", fallback: "If you choose to remove this sensor, it will result in the deletion of your locally stored measurement history, along with the removal of any related sensor settings like name, background image, calibration, and alert configurations.\n\nYou can add this sensor later again, if needed.")
  /// If you choose to remove this shared sensor, the owner of the sensor will be notified and you will not be able to access the sensor anymore.
  /// 
  /// You will also lose any related sensor settings like name, background image and alert configurations.
  public static let removeSharedSensorDescription = RuuviLocalization.tr("Localizable", "remove_shared_sensor_description", fallback: "If you choose to remove this shared sensor, the owner of the sensor will be notified and you will not be able to access the sensor anymore.\n\nYou will also lose any related sensor settings like name, background image and alert configurations.")
  /// Rename
  public static let rename = RuuviLocalization.tr("Localizable", "rename", fallback: "Rename")
  /// Request Code
  public static let requestCode = RuuviLocalization.tr("Localizable", "request_code", fallback: "Request Code")
  /// Using this alert requires you to be signed in to the app, and that you have claimed the ownership of this sensor and it's in the range of Ruuvi Gateway router. iOS devices are unable to indicate signal strength information of received data sent by Ruuvi sensor when sensor is paired and measurements are being received in the background. Realtime Bluetooth signal strength is shown in the app but doesn't affect this alert.
  public static let rssiAlertDescription = RuuviLocalization.tr("Localizable", "rssi_alert_description", fallback: "Using this alert requires you to be signed in to the app, and that you have claimed the ownership of this sensor and it's in the range of Ruuvi Gateway router. iOS devices are unable to indicate signal strength information of received data sent by Ruuvi sensor when sensor is paired and measurements are being received in the background. Realtime Bluetooth signal strength is shown in the app but doesn't affect this alert.")
  /// Ruuvi Cloud
  public static let ruuviCloud = RuuviLocalization.tr("Localizable", "ruuvi_cloud", fallback: "Ruuvi Cloud")
  /// s
  public static let s = RuuviLocalization.tr("Localizable", "s", fallback: "s")
  /// Select from default images
  public static let selectDefaultImage = RuuviLocalization.tr("Localizable", "select_default_image", fallback: "Select from default images")
  /// Select from phone gallery
  public static let selectFromGallery = RuuviLocalization.tr("Localizable", "select_from_gallery", fallback: "Select from phone gallery")
  /// Sensor Details
  public static let sensorDetails = RuuviLocalization.tr("Localizable", "sensor_details", fallback: "Sensor Details")
  /// Sensor not found. Try again.
  public static let sensorNotFoundError = RuuviLocalization.tr("Localizable", "sensor_not_found_error", fallback: "Sensor not found. Try again.")
  /// Signing in to the app has many advantages. Settings will be safely stored to your account:
  public static let sensorsOwnershipAndSettingsStoredInCloud = RuuviLocalization.tr("Localizable", "sensors_ownership_and_settings_stored_in_cloud", fallback: "Signing in to the app has many advantages. Settings will be safely stored to your account:")
  /// Limit alert notifications
  public static let settingsAlertLimitNotification = RuuviLocalization.tr("Localizable", "settings_alert_limit_notification", fallback: "Limit alert notifications")
  /// Trigger Bluetooth alert notification only once per hour even if alert was retriggered.
  public static let settingsAlertLimitNotificationDescription = RuuviLocalization.tr("Localizable", "settings_alert_limit_notification_description", fallback: "Trigger Bluetooth alert notification only once per hour even if alert was retriggered.")
  /// Alert Notifications
  public static let settingsAlertNotifications = RuuviLocalization.tr("Localizable", "settings_alert_notifications", fallback: "Alert Notifications")
  /// Alert Sound
  public static let settingsAlertSound = RuuviLocalization.tr("Localizable", "settings_alert_sound", fallback: "Alert Sound")
  /// System Default
  public static let settingsAlertSoundDefault = RuuviLocalization.tr("Localizable", "settings_alert_sound_default", fallback: "System Default")
  /// Select push notification alert sound.
  public static let settingsAlertSoundDescription = RuuviLocalization.tr("Localizable", "settings_alert_sound_description", fallback: "Select push notification alert sound.")
  /// Ruuvi Alert
  public static let settingsAlertSoundRuuviSpeak = RuuviLocalization.tr("Localizable", "settings_alert_sound_ruuvi_speak", fallback: "Ruuvi Alert")
  /// You can also adjust Notification settings under iOS Settings -> Notifications
  public static let settingsAlertsFooterDescription = RuuviLocalization.tr("Localizable", "settings_alerts_footer_description", fallback: "You can also adjust Notification settings under iOS Settings -> Notifications")
  /// iOS Settings -> Notifications
  public static let settingsAlertsFooterDescriptionLinkMask = RuuviLocalization.tr("Localizable", "settings_alerts_footer_description_link_mask", fallback: "iOS Settings -> Notifications")
  /// Settings & alerts
  public static let settingsAndAlerts = RuuviLocalization.tr("Localizable", "settings_and_alerts", fallback: "Settings & alerts")
  /// Appearance
  public static let settingsAppearance = RuuviLocalization.tr("Localizable", "settings_appearance", fallback: "Appearance")
  /// Email Alerts
  public static let settingsEmailAlerts = RuuviLocalization.tr("Localizable", "settings_email_alerts", fallback: "Email Alerts")
  /// If you are using Ruuvi Cloud and Ruuvi Gateway, you will be able to receive email alerts by enabling this.
  public static let settingsEmailAlertsDescription = RuuviLocalization.tr("Localizable", "settings_email_alerts_description", fallback: "If you are using Ruuvi Cloud and Ruuvi Gateway, you will be able to receive email alerts by enabling this.")
  /// Push Alerts
  public static let settingsPushAlerts = RuuviLocalization.tr("Localizable", "settings_push_alerts", fallback: "Push Alerts")
  /// If you are using Ruuvi Cloud and Ruuvi Gateway, you will be able to receive push alerts by enabling this.
  public static let settingsPushAlertsDescription = RuuviLocalization.tr("Localizable", "settings_push_alerts_description", fallback: "If you are using Ruuvi Cloud and Ruuvi Gateway, you will be able to receive push alerts by enabling this.")
  /// Share pending
  public static let sharePending = RuuviLocalization.tr("Localizable", "share_pending", fallback: "Share pending")
  /// Shared successfully! This email address isn't linked to a Ruuvi account yet. An invite to create a free account has been sent. Once created, you'll see it in the sharee listing.
  public static let sharePendingMessage = RuuviLocalization.tr("Localizable", "share_pending_message", fallback: "Shared successfully! This email address isn't linked to a Ruuvi account yet. An invite to create a free account has been sent. Once created, you'll see it in the sharee listing.")
  /// Shared to %d/%d
  public static func sharedToX(_ p1: Int, _ p2: Int) -> String {
    return RuuviLocalization.tr("Localizable", "shared_to_x", p1, p2, fallback: "Shared to %d/%d")
  }
  /// Continue
  public static let signInContinue = RuuviLocalization.tr("Localizable", "sign_in_continue", fallback: "Continue")
  /// Sign in or create a free Ruuvi account
  public static let signInOrCreateFreeAccount = RuuviLocalization.tr("Localizable", "sign_in_or_create_free_account", fallback: "Sign in or create a free Ruuvi account")
  /// Signal Strength (dBm)
  public static let signalStrengthDbm = RuuviLocalization.tr("Localizable", "signal_strength_dbm", fallback: "Signal Strength (dBm)")
  /// (Signing in is optional)
  public static let signingInIsOptional = RuuviLocalization.tr("Localizable", "signing_in_is_optional", fallback: "(Signing in is optional)")
  /// Simple cards
  public static let simpleCards = RuuviLocalization.tr("Localizable", "simple_cards", fallback: "Simple cards")
  /// Support
  public static let support = RuuviLocalization.tr("Localizable", "support", fallback: "Support")
  /// Synchronisation
  public static let synchronisation = RuuviLocalization.tr("Localizable", "synchronisation", fallback: "Synchronisation")
  /// Synchronised
  public static let synchronized = RuuviLocalization.tr("Localizable", "Synchronized", fallback: "Synchronised")
  /// Loading history from the cloud...
  public static let syncing = RuuviLocalization.tr("Localizable", "Syncing...", fallback: "Loading history from the cloud...")
  /// Take a photo
  public static let takePhoto = RuuviLocalization.tr("Localizable", "take_photo", fallback: "Take a photo")
  /// No password needed.
  public static let toUseAllAppFeatures = RuuviLocalization.tr("Localizable", "to_use_all_app_features", fallback: "No password needed.")
  /// Type your email..
  public static let typeYourEmail = RuuviLocalization.tr("Localizable", "type_your_email", fallback: "Type your email..")
  /// Unclaim
  public static let unclaim = RuuviLocalization.tr("Localizable", "unclaim", fallback: "Unclaim")
  /// Unclaim sensor
  public static let unclaimSensor = RuuviLocalization.tr("Localizable", "unclaim_sensor", fallback: "Unclaim sensor")
  /// Ownership of this sensor has been claimed to your Ruuvi account. Press Unclaim to remove this sensor's settings and related data from your Ruuvi account.
  public static let unclaimSensorDescription = RuuviLocalization.tr("Localizable", "unclaim_sensor_description", fallback: "Ownership of this sensor has been claimed to your Ruuvi account. Press Unclaim to remove this sensor's settings and related data from your Ruuvi account.")
  /// Unique ID:
  public static let uniqueId = RuuviLocalization.tr("Localizable", "unique_id", fallback: "Unique ID:")
  /// Updated
  public static let updated = RuuviLocalization.tr("Localizable", "Updated", fallback: "Updated")
  /// Uploading: %.0f
  public static func uploadingProgress(_ p1: Float) -> String {
    return RuuviLocalization.tr("Localizable", "uploading_progress", p1, fallback: "Uploading: %.0f")
  }
  /// Use BT
  public static let useBluetooth = RuuviLocalization.tr("Localizable", "use_bluetooth", fallback: "Use BT")
  /// Use NFC
  public static let useNfc = RuuviLocalization.tr("Localizable", "use_nfc", fallback: "Use NFC")
  /// No thanks, skip
  public static let useWithoutAccount = RuuviLocalization.tr("Localizable", "use_without_account", fallback: "No thanks, skip")
  /// V
  public static let v = RuuviLocalization.tr("Localizable", "V", fallback: "V")
  /// View
  public static let view = RuuviLocalization.tr("Localizable", "view", fallback: "View")
  /// Benefits
  public static let whyShouldSignIn = RuuviLocalization.tr("Localizable", "why_should_sign_in", fallback: "Benefits")
  /// Yes
  public static let yes = RuuviLocalization.tr("Localizable", "Yes", fallback: "Yes")
  /// °C
  public static let ºC = RuuviLocalization.tr("Localizable", "ºC", fallback: "°C")
  /// °F
  public static let ºF = RuuviLocalization.tr("Localizable", "ºF", fallback: "°F")
  public enum About {
    public enum AboutHelp {
      /// Ruuvi Station is an easy-to-use application that allows you to monitor the measurement data of Ruuvi sensors.
      public static let contents = RuuviLocalization.tr("Localizable", "About.AboutHelp.contents", fallback: "Ruuvi Station is an easy-to-use application that allows you to monitor the measurement data of Ruuvi sensors.")
      /// About / Help
      public static let header = RuuviLocalization.tr("Localizable", "About.AboutHelp.header", fallback: "About / Help")
    }
    public enum DatabaseSize {
      /// Database size: %@
      public static func text(_ p1: Any) -> String {
        return RuuviLocalization.tr("Localizable", "About.DatabaseSize.text", String(describing: p1), fallback: "Database size: %@")
      }
    }
    public enum MeasurementsCount {
      /// Number of locally stored measurements: %d
      public static func text(_ p1: Int) -> String {
        return RuuviLocalization.tr("Localizable", "About.MeasurementsCount.text", p1, fallback: "Number of locally stored measurements: %d")
      }
    }
    public enum More {
      /// Ruuvi's website: ruuvi.com
      /// Ruuvi Forum: f.ruuvi.com
      /// Ruuvi Blog: ruuvi.com/blog
      /// Ruuvi on Twitter: twitter.com/ruuvicom
      public static let contents = RuuviLocalization.tr("Localizable", "About.More.contents", fallback: "Ruuvi's website: ruuvi.com\nRuuvi Forum: f.ruuvi.com\nRuuvi Blog: ruuvi.com/blog\nRuuvi on Twitter: twitter.com/ruuvicom")
      /// More to read
      public static let header = RuuviLocalization.tr("Localizable", "About.More.header", fallback: "More to read")
    }
    public enum OpenSource {
      /// Just like Ruuvi sensors, Ruuvi Station apps are open source. Follow the development and contribute at: github.com/ruuvi
      public static let contents = RuuviLocalization.tr("Localizable", "About.OpenSource.contents", fallback: "Just like Ruuvi sensors, Ruuvi Station apps are open source. Follow the development and contribute at: github.com/ruuvi")
      /// Open-source
      public static let header = RuuviLocalization.tr("Localizable", "About.OpenSource.header", fallback: "Open-source")
    }
    public enum OperationsManual {
      /// Get started using the Ruuvi Station mobile application with our online guides: ruuvi.com/support/station-mobile
      public static let contents = RuuviLocalization.tr("Localizable", "About.OperationsManual.contents", fallback: "Get started using the Ruuvi Station mobile application with our online guides: ruuvi.com/support/station-mobile")
      /// Operations manual
      public static let header = RuuviLocalization.tr("Localizable", "About.OperationsManual.header", fallback: "Operations manual")
    }
    public enum Privacy {
      /// By using the application, you accept Ruuvi's standard terms and conditions: ruuvi.com/terms
      public static let contents = RuuviLocalization.tr("Localizable", "About.Privacy.contents", fallback: "By using the application, you accept Ruuvi's standard terms and conditions: ruuvi.com/terms")
      /// Privacy policy
      public static let header = RuuviLocalization.tr("Localizable", "About.Privacy.header", fallback: "Privacy policy")
    }
    public enum TagsCount {
      /// Added sensors: %d
      public static func text(_ p1: Int) -> String {
        return RuuviLocalization.tr("Localizable", "About.TagsCount.text", p1, fallback: "Added sensors: %d")
      }
    }
    public enum Troubleshooting {
      /// Find help using the Ruuvi Station apps, Ruuvi products and Ruuvi Cloud service from our support center: ruuvi.com/support
      public static let contents = RuuviLocalization.tr("Localizable", "About.Troubleshooting.contents", fallback: "Find help using the Ruuvi Station apps, Ruuvi products and Ruuvi Cloud service from our support center: ruuvi.com/support")
      /// Troubleshooting
      public static let header = RuuviLocalization.tr("Localizable", "About.Troubleshooting.header", fallback: "Troubleshooting")
    }
    public enum Version {
      /// Version
      public static let text = RuuviLocalization.tr("Localizable", "About.Version.text", fallback: "Version")
    }
  }
  public enum Background {
    public enum Interval {
      public enum Every {
        /// every
        public static let string = RuuviLocalization.tr("Localizable", "Background.Interval.Every.string", fallback: "every")
      }
      public enum Min {
        /// min
        public static let string = RuuviLocalization.tr("Localizable", "Background.Interval.Min.string", fallback: "min")
      }
      public enum Sec {
        /// sec
        public static let string = RuuviLocalization.tr("Localizable", "Background.Interval.Sec.string", fallback: "sec")
      }
    }
    public enum KeepConnection {
      /// Keep the Connection
      public static let title = RuuviLocalization.tr("Localizable", "Background.KeepConnection.title", fallback: "Keep the Connection")
    }
    public enum PresentNotifications {
      /// Show Notifications
      public static let title = RuuviLocalization.tr("Localizable", "Background.PresentNotifications.title", fallback: "Show Notifications")
    }
    public enum ReadRSSITitle {
      /// Read RSSI
      public static let title = RuuviLocalization.tr("Localizable", "Background.readRSSITitle.title", fallback: "Read RSSI")
    }
  }
  public enum BluetoothError {
    /// Disconnected
    public static let disconnected = RuuviLocalization.tr("Localizable", "BluetoothError.disconnected", fallback: "Disconnected")
  }
  public enum Cards {
    public enum Alert {
      public enum AlreadyLoggedIn {
        /// User %@ is already signed in. If you'd like to use a different account, please sign out first and then try again.
        public static func message(_ p1: Any) -> String {
          return RuuviLocalization.tr("Localizable", "Cards.Alert.AlreadyLoggedIn.message", String(describing: p1), fallback: "User %@ is already signed in. If you'd like to use a different account, please sign out first and then try again.")
        }
      }
    }
    public enum BluetoothDisabledAlert {
      /// Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.
      public static let message = RuuviLocalization.tr("Localizable", "Cards.BluetoothDisabledAlert.message", fallback: "Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.")
      /// Bluetooth is not enabled
      public static let title = RuuviLocalization.tr("Localizable", "Cards.BluetoothDisabledAlert.title", fallback: "Bluetooth is not enabled")
    }
    public enum Connected {
      /// Connected
      public static let title = RuuviLocalization.tr("Localizable", "Cards.Connected.title", fallback: "Connected")
    }
    public enum Error {
      public enum ReverseGeocodingFailed {
        /// Failed to load data for Virtual Sensor. Reverse geocode operation limit exceeded.
        public static let message = RuuviLocalization.tr("Localizable", "Cards.Error.ReverseGeocodingFailed.message", fallback: "Failed to load data for Virtual Sensor. Reverse geocode operation limit exceeded.")
      }
    }
    public enum KeepConnectionDialog {
      /// Seems like you are running a connectable firmware on your Ruuvi device. Would you like to keep the connection open to this Ruuvi device in the background? This will allow histograms and alerts to work even when the application is minimised.
      public static let message = RuuviLocalization.tr("Localizable", "Cards.KeepConnectionDialog.message", fallback: "Seems like you are running a connectable firmware on your Ruuvi device. Would you like to keep the connection open to this Ruuvi device in the background? This will allow histograms and alerts to work even when the application is minimised.")
      public enum Dismiss {
        /// Cancel
        public static let title = RuuviLocalization.tr("Localizable", "Cards.KeepConnectionDialog.Dismiss.title", fallback: "Cancel")
      }
      public enum KeepConnection {
        /// Keep the Connection
        public static let title = RuuviLocalization.tr("Localizable", "Cards.KeepConnectionDialog.KeepConnection.title", fallback: "Keep the Connection")
      }
    }
    public enum LegacyFirmwareUpdateDialog {
      /// Looks like your sensor is using an old firmware software version. To access new features such as history graphs, alerts and cloud services, updating is mandatory.
      public static let message = RuuviLocalization.tr("Localizable", "Cards.LegacyFirmwareUpdateDialog.message", fallback: "Looks like your sensor is using an old firmware software version. To access new features such as history graphs, alerts and cloud services, updating is mandatory.")
      public enum CancelConfirmation {
        /// Are you sure? Without updating, you won't be able to claim ownership of the sensor, download history graphs and set alerts. The update also includes bug fixes. If you cancel now, you can start the update process again from the sensor's settings page.
        public static let message = RuuviLocalization.tr("Localizable", "Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message", fallback: "Are you sure? Without updating, you won't be able to claim ownership of the sensor, download history graphs and set alerts. The update also includes bug fixes. If you cancel now, you can start the update process again from the sensor's settings page.")
      }
      public enum CheckForUpdate {
        /// Check for update
        public static let title = RuuviLocalization.tr("Localizable", "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title", fallback: "Check for update")
      }
    }
    public enum Movements {
      /// movements
      public static let title = RuuviLocalization.tr("Localizable", "Cards.Movements.title", fallback: "movements")
    }
    public enum NoSensors {
      /// No sensors added
      /// Press here to add sensors
      public static let title = RuuviLocalization.tr("Localizable", "Cards.NoSensors.title", fallback: "No sensors added\nPress here to add sensors")
    }
    public enum UpdatedLabel {
      public enum NoData {
        /// No data during the last 10 days
        public static let message = RuuviLocalization.tr("Localizable", "Cards.UpdatedLabel.NoData.message", fallback: "No data during the last 10 days")
      }
    }
    public enum WebTagAPILimitExcededError {
      public enum Alert {
        /// Please try again in 5 minutes
        public static let message = RuuviLocalization.tr("Localizable", "Cards.WebTagAPILimitExcededError.Alert.message", fallback: "Please try again in 5 minutes")
        /// Too many requests
        public static let title = RuuviLocalization.tr("Localizable", "Cards.WebTagAPILimitExcededError.Alert.title", fallback: "Too many requests")
      }
    }
  }
  public enum ChartSettings {
    public enum AllPoints {
      /// Charts may be updated slowly when enabled.
      public static let description = RuuviLocalization.tr("Localizable", "ChartSettings.AllPoints.description", fallback: "Charts may be updated slowly when enabled.")
      /// Show all measurements
      public static let title = RuuviLocalization.tr("Localizable", "ChartSettings.AllPoints.title", fallback: "Show all measurements")
    }
    public enum DrawDots {
      /// Small dots will help to understand when measurements were collected.
      public static let description = RuuviLocalization.tr("Localizable", "ChartSettings.DrawDots.description", fallback: "Small dots will help to understand when measurements were collected.")
      /// Show datapoints
      public static let title = RuuviLocalization.tr("Localizable", "ChartSettings.DrawDots.title", fallback: "Show datapoints")
    }
    public enum Duration {
      /// Configure the period of history to be shown on chart from 1 to 10 days.
      public static let description = RuuviLocalization.tr("Localizable", "ChartSettings.Duration.description", fallback: "Configure the period of history to be shown on chart from 1 to 10 days.")
      /// Chart History View Period
      public static let title = RuuviLocalization.tr("Localizable", "ChartSettings.Duration.title", fallback: "Chart History View Period")
    }
  }
  public enum CoreError {
    /// Failed to get current location
    public static let failedToGetCurrentLocation = RuuviLocalization.tr("Localizable", "CoreError.failedToGetCurrentLocation", fallback: "Failed to get current location")
    /// Failed to get data from response
    public static let failedToGetDataFromResponse = RuuviLocalization.tr("Localizable", "CoreError.failedToGetDataFromResponse", fallback: "Failed to get data from response")
    /// Failed to get background directory
    public static let failedToGetDocumentsDirectory = RuuviLocalization.tr("Localizable", "CoreError.failedToGetDocumentsDirectory", fallback: "Failed to get background directory")
    /// Failed to get PNG representation
    public static let failedToGetPngRepresentation = RuuviLocalization.tr("Localizable", "CoreError.failedToGetPngRepresentation", fallback: "Failed to get PNG representation")
    /// Missing permission for Location Services
    public static let locationPermissionDenied = RuuviLocalization.tr("Localizable", "CoreError.locationPermissionDenied", fallback: "Missing permission for Location Services")
    /// Location permission authorisation status is not determined
    public static let locationPermissionNotDetermined = RuuviLocalization.tr("Localizable", "CoreError.locationPermissionNotDetermined", fallback: "Location permission authorisation status is not determined")
    /// Object invalidated
    public static let objectInvalidated = RuuviLocalization.tr("Localizable", "CoreError.objectInvalidated", fallback: "Object invalidated")
    /// Object not found
    public static let objectNotFound = RuuviLocalization.tr("Localizable", "CoreError.objectNotFound", fallback: "Object not found")
    /// Unable to send email
    public static let unableToSendEmail = RuuviLocalization.tr("Localizable", "CoreError.unableToSendEmail", fallback: "Unable to send email")
  }
  public enum DFUUIView {
    /// You are running the latest firmware version, no need to update
    public static let alreadyOnLatest = RuuviLocalization.tr("Localizable", "DFUUIView.alreadyOnLatest", fallback: "You are running the latest firmware version, no need to update")
    /// Current version:
    public static let currentTitle = RuuviLocalization.tr("Localizable", "DFUUIView.currentTitle", fallback: "Current version:")
    /// Do not close the app or power off the sensor during the update.
    public static let doNotCloseTitle = RuuviLocalization.tr("Localizable", "DFUUIView.doNotCloseTitle", fallback: "Do not close the app or power off the sensor during the update.")
    /// Downloading the latest firmware to be updated...
    public static let downloadingTitle = RuuviLocalization.tr("Localizable", "DFUUIView.downloadingTitle", fallback: "Downloading the latest firmware to be updated...")
    /// Latest available Ruuvi Firmware version:
    public static let latestTitle = RuuviLocalization.tr("Localizable", "DFUUIView.latestTitle", fallback: "Latest available Ruuvi Firmware version:")
    /// 2. Locate the small round black buttons on the white circuit board; older Ruuvi sensors have 2 buttons labelled “R” and “B” while newer ones have only one button without a label.
    public static let locateBootButtonTitle = RuuviLocalization.tr("Localizable", "DFUUIView.locateBootButtonTitle", fallback: "2. Locate the small round black buttons on the white circuit board; older Ruuvi sensors have 2 buttons labelled “R” and “B” while newer ones have only one button without a label.")
    /// Firmware Update
    public static let navigationTitle = RuuviLocalization.tr("Localizable", "DFUUIView.navigationTitle", fallback: "Firmware Update")
    /// Your sensor doesn't report its current firmware version. Either you're not in its Bluetooth range, it's connected to another phone, or it's running a very old firmware version.
    public static let notReportingDescription = RuuviLocalization.tr("Localizable", "DFUUIView.notReportingDescription", fallback: "Your sensor doesn't report its current firmware version. Either you're not in its Bluetooth range, it's connected to another phone, or it's running a very old firmware version.")
    /// 1. Open the cover of your Ruuvi sensor
    public static let openCoverTitle = RuuviLocalization.tr("Localizable", "DFUUIView.openCoverTitle", fallback: "1. Open the cover of your Ruuvi sensor")
    /// Prepare your sensor
    public static let prepareTitle = RuuviLocalization.tr("Localizable", "DFUUIView.prepareTitle", fallback: "Prepare your sensor")
    /// Searching for a sensor
    public static let searchingTitle = RuuviLocalization.tr("Localizable", "DFUUIView.searchingTitle", fallback: "Searching for a sensor")
    /// 3. Set the sensor to updating mode:
    public static let setUpdatingModeTitle = RuuviLocalization.tr("Localizable", "DFUUIView.setUpdatingModeTitle", fallback: "3. Set the sensor to updating mode:")
    /// Start the update
    public static let startTitle = RuuviLocalization.tr("Localizable", "DFUUIView.startTitle", fallback: "Start the update")
    /// Start update process
    public static let startUpdateProcess = RuuviLocalization.tr("Localizable", "DFUUIView.startUpdateProcess", fallback: "Start update process")
    /// Update successful
    public static let successfulTitle = RuuviLocalization.tr("Localizable", "DFUUIView.successfulTitle", fallback: "Update successful")
    /// 3.2. If your sensor has a single button: keep the button pressed for 10 seconds.
    public static let toBootModeOneButtonDescription = RuuviLocalization.tr("Localizable", "DFUUIView.toBootModeOneButtonDescription", fallback: "3.2. If your sensor has a single button: keep the button pressed for 10 seconds.")
    /// 4. If set successfully, you will see a solid red light lit on the circuit board and the button in the app will change to “Start the update”.
    public static let toBootModeSuccessTitle = RuuviLocalization.tr("Localizable", "DFUUIView.toBootModeSuccessTitle", fallback: "4. If set successfully, you will see a solid red light lit on the circuit board and the button in the app will change to “Start the update”.")
    /// 3.1. If your sensor has 2 buttons: keep “B” button pressed while tapping button “R” momentarily. Release button “B”.
    public static let toBootModeTwoButtonsDescription = RuuviLocalization.tr("Localizable", "DFUUIView.toBootModeTwoButtonsDescription", fallback: "3.1. If your sensor has 2 buttons: keep “B” button pressed while tapping button “R” momentarily. Release button “B”.")
    /// Updating...
    public static let updatingTitle = RuuviLocalization.tr("Localizable", "DFUUIView.updatingTitle", fallback: "Updating...")
    public enum DBMigration {
      public enum Error {
        /// The update was successful, but an unexpected database migration error occurred. To continue using this sensor, please remove it from the app and then add it again.
        public static let message = RuuviLocalization.tr("Localizable", "DFUUIView.DBMigration.Error.message", fallback: "The update was successful, but an unexpected database migration error occurred. To continue using this sensor, please remove it from the app and then add it again.")
      }
    }
    public enum LowBattery {
      public enum Warning {
        /// Sensor's battery voltage seems to be low and the firmware update process may fail. We recommend to replace the battery before updating.
        public static let message = RuuviLocalization.tr("Localizable", "DFUUIView.lowBattery.warning.message", fallback: "Sensor's battery voltage seems to be low and the firmware update process may fail. We recommend to replace the battery before updating.")
      }
    }
  }
  public enum Defaults {
    public enum AlertsMuteInterval {
      /// Alerts Mute Interval
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.AlertsMuteInterval.title", fallback: "Alerts Mute Interval")
    }
    public enum AlertsRepeatInterval {
      /// Alerts Interval
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.AlertsRepeatInterval.title", fallback: "Alerts Interval")
    }
    public enum AppLaunchRequiredForReview {
      public enum Count {
        /// App launch count to ask for review for the first time
        public static let title = RuuviLocalization.tr("Localizable", "Defaults.AppLaunchRequiredForReview.Count.title", fallback: "App launch count to ask for review for the first time")
      }
    }
    public enum AskReviewIfLaunchDivisibleBy {
      public enum Count {
        /// Ask review if app launch divisible by
        public static let title = RuuviLocalization.tr("Localizable", "Defaults.AskReviewIfLaunchDivisibleBy.Count.title", fallback: "Ask review if app launch divisible by")
      }
    }
    public enum CardsSwipeHint {
      /// Cards Swipe Hint Was Shown
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.CardsSwipeHint.title", fallback: "Cards Swipe Hint Was Shown")
    }
    public enum ChartDurationHours {
      /// Chart Duration
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.ChartDurationHours.title", fallback: "Chart Duration")
    }
    public enum ChartIntervalSeconds {
      /// Chart Interval
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.ChartIntervalSeconds.title", fallback: "Chart Interval")
    }
    public enum ChartsSwipeInstructionWasShown {
      /// Charts Swipe Hint Was Shown
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.ChartsSwipeInstructionWasShown.title", fallback: "Charts Swipe Hint Was Shown")
    }
    public enum ConnectionTimeout {
      /// Connection Timeout
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.ConnectionTimeout.title", fallback: "Connection Timeout")
    }
    public enum DashboardTapActionChart {
      /// Show Chart on Dashboard Card Tap
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.DashboardTapActionChart.title", fallback: "Show Chart on Dashboard Card Tap")
    }
    public enum DevServer {
      /// Changing Ruuvi Cloud endpoint requires signing out from current session and restart the app. Are you sure?
      public static let message = RuuviLocalization.tr("Localizable", "Defaults.DevServer.message", fallback: "Changing Ruuvi Cloud endpoint requires signing out from current session and restart the app. Are you sure?")
      /// Use Dev Server
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.DevServer.title", fallback: "Use Dev Server")
    }
    public enum HideNFC {
      /// Hide NFC Option for sensor contest
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.HideNFC.title", fallback: "Hide NFC Option for sensor contest")
    }
    public enum Interval {
      public enum Hour {
        /// h
        public static let string = RuuviLocalization.tr("Localizable", "Defaults.Interval.Hour.string", fallback: "h")
      }
      public enum Min {
        /// min
        public static let string = RuuviLocalization.tr("Localizable", "Defaults.Interval.Min.string", fallback: "min")
      }
      public enum Sec {
        /// sec
        public static let string = RuuviLocalization.tr("Localizable", "Defaults.Interval.Sec.string", fallback: "sec")
      }
    }
    public enum PruningOffsetHours {
      /// Pruning Offset Hours
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.PruningOffsetHours.title", fallback: "Pruning Offset Hours")
    }
    public enum ServiceTimeout {
      /// Service Timeout
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.ServiceTimeout.title", fallback: "Service Timeout")
    }
    public enum ShowEmailAlertsSettings {
      /// Show email alerts settings
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.ShowEmailAlertsSettings.title", fallback: "Show email alerts settings")
    }
    public enum ShowPushAlertsSettings {
      /// Show push alerts settings
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.ShowPushAlertsSettings.title", fallback: "Show push alerts settings")
    }
    public enum UserAuthorized {
      /// User Authorized
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.UserAuthorized.title", fallback: "User Authorized")
    }
    public enum WebPullInterval {
      /// Web Alerts Interval
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.WebPullInterval.title", fallback: "Web Alerts Interval")
    }
    public enum WelcomeShown {
      /// Welcome Displayed
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.WelcomeShown.title", fallback: "Welcome Displayed")
    }
    public enum NavigationItem {
      /// Defaults
      public static let title = RuuviLocalization.tr("Localizable", "Defaults.navigationItem.title", fallback: "Defaults")
    }
  }
  public enum Devices {
    /// Token Id
    public static let tokenId = RuuviLocalization.tr("Localizable", "Devices.tokenId", fallback: "Token Id")
  }
  public enum DfuDevicesScanner {
    public enum BluetoothDisabled {
      /// (Bluetooth is disabled)
      public static let text = RuuviLocalization.tr("Localizable", "DfuDevicesScanner.BluetoothDisabled.text", fallback: "(Bluetooth is disabled)")
    }
    public enum BluetoothDisabledAlert {
      /// Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.
      public static let message = RuuviLocalization.tr("Localizable", "DfuDevicesScanner.BluetoothDisabledAlert.message", fallback: "Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.")
      /// Bluetooth is not enabled
      public static let title = RuuviLocalization.tr("Localizable", "DfuDevicesScanner.BluetoothDisabledAlert.title", fallback: "Bluetooth is not enabled")
    }
    public enum Description {
      /// Find and select sensor "RuuviBoot".
      public static let text = RuuviLocalization.tr("Localizable", "DfuDevicesScanner.Description.text", fallback: "Find and select sensor \"RuuviBoot\".")
    }
    public enum NoDevice {
      /// (No sensors in Bluetooth range)
      public static let text = RuuviLocalization.tr("Localizable", "DfuDevicesScanner.NoDevice.text", fallback: "(No sensors in Bluetooth range)")
    }
    public enum Title {
      /// Devices
      public static let text = RuuviLocalization.tr("Localizable", "DfuDevicesScanner.Title.text", fallback: "Devices")
    }
  }
  public enum DfuFlash {
    public enum Cancel {
      /// CANCEL
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Cancel.text", fallback: "CANCEL")
    }
    public enum CancelAlert {
      /// Are you sure you want to cancel the firmware update process?
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.CancelAlert.text", fallback: "Are you sure you want to cancel the firmware update process?")
    }
    public enum Finish {
      /// FINISH
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Finish.text", fallback: "FINISH")
    }
    public enum FinishGuide {
      /// Firmware update process has been completed successfully.
      /// Your RuuviTag sensor is ready for use!
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.FinishGuide.text", fallback: "Firmware update process has been completed successfully.\nYour RuuviTag sensor is ready for use!")
    }
    public enum Firmware {
      public enum BootloaderSize {
        /// Bootloader size
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Firmware.BootloaderSize.text", fallback: "Bootloader size")
      }
      public enum FileName {
        /// File name
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Firmware.FileName.text", fallback: "File name")
      }
      public enum Parts {
        /// Parts
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Firmware.Parts.text", fallback: "Parts")
      }
      public enum Size {
        /// Size
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Firmware.Size.text", fallback: "Size")
      }
      public enum SoftDeviceSize {
        /// Soft Device size
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Firmware.SoftDeviceSize.text", fallback: "Soft Device size")
      }
    }
    public enum FirmwareSelectionGuide {
      /// Locate the previously downloaded ZIP file on your mobile device.
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.FirmwareSelectionGuide.text", fallback: "Locate the previously downloaded ZIP file on your mobile device.")
    }
    public enum OpenDocumentPicker {
      /// OPEN DOCUMENT PICKER
      public static let title = RuuviLocalization.tr("Localizable", "DfuFlash.OpenDocumentPicker.title", fallback: "OPEN DOCUMENT PICKER")
    }
    public enum Progress {
      /// Progress
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Progress.text", fallback: "Progress")
    }
    public enum Start {
      /// Start
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Start.text", fallback: "Start")
    }
    public enum Step {
      /// Step
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Step.text", fallback: "Step")
    }
    public enum Steps {
      public enum Completed {
        /// Completed
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Steps.Completed.text", fallback: "Completed")
      }
      public enum PackageSelection {
        /// Package selection
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Steps.PackageSelection.text", fallback: "Package selection")
      }
      public enum ReadyForUpload {
        /// Ready For upload
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Steps.ReadyForUpload.text", fallback: "Ready For upload")
      }
      public enum Uploading {
        /// Uploading
        public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Steps.Uploading.text", fallback: "Uploading")
      }
    }
    public enum Title {
      /// DFU Flash
      public static let text = RuuviLocalization.tr("Localizable", "DfuFlash.Title.text", fallback: "DFU Flash")
    }
  }
  public enum DiscoverTable {
    public enum BluetoothDisabledAlert {
      /// Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.
      public static let message = RuuviLocalization.tr("Localizable", "DiscoverTable.BluetoothDisabledAlert.message", fallback: "Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.")
      /// Bluetooth is not enabled
      public static let title = RuuviLocalization.tr("Localizable", "DiscoverTable.BluetoothDisabledAlert.title", fallback: "Bluetooth is not enabled")
    }
    public enum GetMoreSensors {
      public enum Button {
        /// Buy Ruuvi Sensors
        public static let title = RuuviLocalization.tr("Localizable", "DiscoverTable.GetMoreSensors.button.title", fallback: "Buy Ruuvi Sensors")
      }
    }
    public enum NavigationItem {
      /// Add a New Sensor
      public static let title = RuuviLocalization.tr("Localizable", "DiscoverTable.NavigationItem.title", fallback: "Add a New Sensor")
    }
    public enum NoDevicesSection {
      public enum BluetoothDisabled {
        /// (Bluetooth is disabled)
        public static let text = RuuviLocalization.tr("Localizable", "DiscoverTable.NoDevicesSection.BluetoothDisabled.text", fallback: "(Bluetooth is disabled)")
      }
      public enum NotFound {
        /// (No sensors in Bluetooth range)
        public static let text = RuuviLocalization.tr("Localizable", "DiscoverTable.NoDevicesSection.NotFound.text", fallback: "(No sensors in Bluetooth range)")
      }
    }
    public enum RuuviDevice {
      /// Ruuvi
      public static let `prefix` = RuuviLocalization.tr("Localizable", "DiscoverTable.RuuviDevice.prefix", fallback: "Ruuvi")
    }
    public enum SectionTitle {
      /// Nearby Ruuvi sensors
      public static let devices = RuuviLocalization.tr("Localizable", "DiscoverTable.SectionTitle.Devices", fallback: "Nearby Ruuvi sensors")
      /// Virtual sensors
      public static let webTags = RuuviLocalization.tr("Localizable", "DiscoverTable.SectionTitle.WebTags", fallback: "Virtual sensors")
    }
    public enum WebTagsInfoDialog {
      /// Virtual Sensors show public weather data provided by local weather stations.
      public static let message = RuuviLocalization.tr("Localizable", "DiscoverTable.WebTagsInfoDialog.message", fallback: "Virtual Sensors show public weather data provided by local weather stations.")
    }
  }
  public enum ErrorPresenterAlert {
    /// Error
    public static let error = RuuviLocalization.tr("Localizable", "ErrorPresenterAlert.Error", fallback: "Error")
    /// OK
    public static let ok = RuuviLocalization.tr("Localizable", "ErrorPresenterAlert.OK", fallback: "OK")
  }
  public enum ExpectedError {
    /// Unable to remove a connected device that is not reachable. Please check your Bluetooth connection.
    public static let failedToDeleteTag = RuuviLocalization.tr("Localizable", "ExpectedError.failedToDeleteTag", fallback: "Unable to remove a connected device that is not reachable. Please check your Bluetooth connection.")
    /// App is already in the process of syncing logs with this sensor
    public static let isAlreadySyncingLogsWithThisTag = RuuviLocalization.tr("Localizable", "ExpectedError.isAlreadySyncingLogsWithThisTag", fallback: "App is already in the process of syncing logs with this sensor")
    /// Missing OpenWeatherMap API Key. Please get one from openweathermap.org website and enter it in the station/Classes/Networking/Assembly/Networking.plist file
    public static let missingOpenWeatherMapAPIKey = RuuviLocalization.tr("Localizable", "ExpectedError.missingOpenWeatherMapAPIKey", fallback: "Missing OpenWeatherMap API Key. Please get one from openweathermap.org website and enter it in the station/Classes/Networking/Assembly/Networking.plist file")
  }
  public enum ExportService {
    /// Acceleration X
    public static let accelerationX = RuuviLocalization.tr("Localizable", "ExportService.AccelerationX", fallback: "Acceleration X")
    /// Acceleration Y
    public static let accelerationY = RuuviLocalization.tr("Localizable", "ExportService.AccelerationY", fallback: "Acceleration Y")
    /// Acceleration Z
    public static let accelerationZ = RuuviLocalization.tr("Localizable", "ExportService.AccelerationZ", fallback: "Acceleration Z")
    /// Date
    public static let date = RuuviLocalization.tr("Localizable", "ExportService.Date", fallback: "Date")
    /// Dew point (%@)
    public static func dewPoint(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "ExportService.DewPoint", String(describing: p1), fallback: "Dew point (%@)")
    }
    /// Humidity (%@)
    public static func humidity(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "ExportService.Humidity", String(describing: p1), fallback: "Humidity (%@)")
    }
    /// ISO8601
    public static let iso8601 = RuuviLocalization.tr("Localizable", "ExportService.ISO8601", fallback: "ISO8601")
    /// Measurement Sequence Number
    public static let measurementSequenceNumber = RuuviLocalization.tr("Localizable", "ExportService.MeasurementSequenceNumber", fallback: "Measurement Sequence Number")
    /// Movement Counter
    public static let movementCounter = RuuviLocalization.tr("Localizable", "ExportService.MovementCounter", fallback: "Movement Counter")
    /// Pressure (%@)
    public static func pressure(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "ExportService.Pressure", String(describing: p1), fallback: "Pressure (%@)")
    }
    /// Temperature (%@)
    public static func temperature(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "ExportService.Temperature", String(describing: p1), fallback: "Temperature (%@)")
    }
    /// TX Power
    public static let txPower = RuuviLocalization.tr("Localizable", "ExportService.TXPower", fallback: "TX Power")
    /// Voltage (V)
    public static let voltage = RuuviLocalization.tr("Localizable", "ExportService.Voltage", fallback: "Voltage (V)")
  }
  public enum Foreground {
    public enum Interval {
      public enum All {
        /// All
        public static let string = RuuviLocalization.tr("Localizable", "Foreground.Interval.All.string", fallback: "All")
      }
      public enum Every {
        /// Every
        public static let string = RuuviLocalization.tr("Localizable", "Foreground.Interval.Every.string", fallback: "Every")
      }
      public enum Min {
        /// min
        public static let string = RuuviLocalization.tr("Localizable", "Foreground.Interval.Min.string", fallback: "min")
      }
    }
    public enum NavigationItem {
      /// Foreground
      public static let title = RuuviLocalization.tr("Localizable", "Foreground.navigationItem.title", fallback: "Foreground")
    }
  }
  public enum ForegroundRow {
    public enum Advertisement {
      /// ADVERTISEMENTS
      public static let section = RuuviLocalization.tr("Localizable", "ForegroundRow.advertisement.section", fallback: "ADVERTISEMENTS")
      /// Save advertisements
      public static let title = RuuviLocalization.tr("Localizable", "ForegroundRow.advertisement.title", fallback: "Save advertisements")
    }
    public enum Connection {
      /// LOGS
      public static let section = RuuviLocalization.tr("Localizable", "ForegroundRow.connection.section", fallback: "LOGS")
      /// Connect and sync logs
      public static let title = RuuviLocalization.tr("Localizable", "ForegroundRow.connection.title", fallback: "Connect and sync logs")
    }
    public enum WebTags {
      /// VIRTUAL SENSORS
      public static let section = RuuviLocalization.tr("Localizable", "ForegroundRow.webTags.section", fallback: "VIRTUAL SENSORS")
      /// Load and save from web
      public static let title = RuuviLocalization.tr("Localizable", "ForegroundRow.webTags.title", fallback: "Load and save from web")
    }
  }
  public enum Heartbeat {
    public enum Interval {
      public enum All {
        /// All
        public static let string = RuuviLocalization.tr("Localizable", "Heartbeat.Interval.All.string", fallback: "All")
      }
      public enum Every {
        /// every
        public static let string = RuuviLocalization.tr("Localizable", "Heartbeat.Interval.Every.string", fallback: "every")
      }
      public enum Min {
        /// min
        public static let string = RuuviLocalization.tr("Localizable", "Heartbeat.Interval.Min.string", fallback: "min")
      }
      public enum Sec {
        /// sec
        public static let string = RuuviLocalization.tr("Localizable", "Heartbeat.Interval.Sec.string", fallback: "sec")
      }
    }
    public enum ReadRSSITitle {
      /// Read RSSI
      public static let title = RuuviLocalization.tr("Localizable", "Heartbeat.readRSSITitle.title", fallback: "Read RSSI")
    }
  }
  public enum HumidityCalibration {
    public enum Button {
      public enum Calibrate {
        /// Calibrate
        public static let title = RuuviLocalization.tr("Localizable", "HumidityCalibration.Button.Calibrate.title", fallback: "Calibrate")
      }
      public enum Clear {
        /// Clear
        public static let title = RuuviLocalization.tr("Localizable", "HumidityCalibration.Button.Clear.title", fallback: "Clear")
      }
      public enum Close {
        /// Close
        public static let title = RuuviLocalization.tr("Localizable", "HumidityCalibration.Button.Close.title", fallback: "Close")
      }
    }
    public enum CalibrationConfirmationAlert {
      /// You are going to calibrate humidity offset. Tap "Confirm" to continue
      public static let message = RuuviLocalization.tr("Localizable", "HumidityCalibration.CalibrationConfirmationAlert.message", fallback: "You are going to calibrate humidity offset. Tap \"Confirm\" to continue")
      /// Are you sure?
      public static let title = RuuviLocalization.tr("Localizable", "HumidityCalibration.CalibrationConfirmationAlert.title", fallback: "Are you sure?")
    }
    public enum ClearCalibrationConfirmationAlert {
      /// You are going to clear humidity offset. This can't be undone. Tap "Confirm" to continue.
      public static let message = RuuviLocalization.tr("Localizable", "HumidityCalibration.ClearCalibrationConfirmationAlert.message", fallback: "You are going to clear humidity offset. This can't be undone. Tap \"Confirm\" to continue.")
      /// Are you sure?
      public static let title = RuuviLocalization.tr("Localizable", "HumidityCalibration.ClearCalibrationConfirmationAlert.title", fallback: "Are you sure?")
    }
    public enum Description {
      /// In order to measure relative humidity as accurately as possible, a sodium chloride (salt) calibration is recommended. See video tutorials on how to easily do this at home.
      public static let text = RuuviLocalization.tr("Localizable", "HumidityCalibration.Description.text", fallback: "In order to measure relative humidity as accurately as possible, a sodium chloride (salt) calibration is recommended. See video tutorials on how to easily do this at home.")
    }
    public enum Label {
      public enum Note {
        /// Note that calibration data will be stored locally in your mobile device. After Ruuvi Station uninstall and install, you may need to recalibrate.
        public static let text = RuuviLocalization.tr("Localizable", "HumidityCalibration.Label.note.text", fallback: "Note that calibration data will be stored locally in your mobile device. After Ruuvi Station uninstall and install, you may need to recalibrate.")
      }
    }
    public enum VideoTutorials {
      /// video tutorials
      public static let link = RuuviLocalization.tr("Localizable", "HumidityCalibration.VideoTutorials.link", fallback: "video tutorials")
    }
    public enum LastCalibrationDate {
      /// Calibrated: %@
      public static func format(_ p1: Any) -> String {
        return RuuviLocalization.tr("Localizable", "HumidityCalibration.lastCalibrationDate.format", String(describing: p1), fallback: "Calibrated: %@")
      }
    }
  }
  public enum HumidityUnit {
    public enum Dew {
      /// Dew point (%@)
      public static func title(_ p1: Any) -> String {
        return RuuviLocalization.tr("Localizable", "HumidityUnit.Dew.title", String(describing: p1), fallback: "Dew point (%@)")
      }
    }
    public enum Percent {
      /// Relative (%)
      public static let title = RuuviLocalization.tr("Localizable", "HumidityUnit.Percent.title", fallback: "Relative (%)")
    }
    public enum Gm3 {
      /// Absolute (g/m³)
      public static let title = RuuviLocalization.tr("Localizable", "HumidityUnit.gm3.title", fallback: "Absolute (g/m³)")
    }
  }
  public enum Interval {
    public enum Day {
      /// Day
      public static let string = RuuviLocalization.tr("Localizable", "Interval.Day.string", fallback: "Day")
    }
    public enum Days {
      /// Days
      public static let string = RuuviLocalization.tr("Localizable", "Interval.Days.string", fallback: "Days")
    }
  }
  public enum Language {
    /// English
    public static let english = RuuviLocalization.tr("Localizable", "Language.English", fallback: "English")
    /// Suomi
    public static let finnish = RuuviLocalization.tr("Localizable", "Language.Finnish", fallback: "Suomi")
    /// Français
    public static let french = RuuviLocalization.tr("Localizable", "Language.French", fallback: "Français")
    /// Deutsch
    public static let german = RuuviLocalization.tr("Localizable", "Language.German", fallback: "Deutsch")
    /// Русский
    public static let russian = RuuviLocalization.tr("Localizable", "Language.Russian", fallback: "Русский")
    /// Svenska
    public static let swedish = RuuviLocalization.tr("Localizable", "Language.Swedish", fallback: "Svenska")
  }
  public enum LocalNotificationsManager {
    public enum DidConnect {
      /// Connected
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.DidConnect.title", fallback: "Connected")
    }
    public enum DidDisconnect {
      /// Disconnected
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.DidDisconnect.title", fallback: "Disconnected")
    }
    public enum DidMove {
      /// Movement detected!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.DidMove.title", fallback: "Movement detected!")
    }
    public enum Disable {
      /// Turn off
      public static let button = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.Disable.button", fallback: "Turn off")
    }
    public enum HighDewPoint {
      /// Dew Point is too high!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.HighDewPoint.title", fallback: "Dew Point is too high!")
    }
    public enum HighHumidity {
      /// Air Humidity is too high!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.HighHumidity.title", fallback: "Air Humidity is too high!")
    }
    public enum HighPressure {
      /// Air Pressure is too high!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.HighPressure.title", fallback: "Air Pressure is too high!")
    }
    public enum HighSignal {
      /// Signal strength is too high!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.HighSignal.title", fallback: "Signal strength is too high!")
    }
    public enum HighTemperature {
      /// Temperature is too high!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.HighTemperature.title", fallback: "Temperature is too high!")
    }
    public enum LowDewPoint {
      /// Dew Point is too low!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.LowDewPoint.title", fallback: "Dew Point is too low!")
    }
    public enum LowHumidity {
      /// Air Humidity is too low!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.LowHumidity.title", fallback: "Air Humidity is too low!")
    }
    public enum LowPressure {
      /// Air Pressure is too low!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.LowPressure.title", fallback: "Air Pressure is too low!")
    }
    public enum LowSignal {
      /// Signal strength is too low!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.LowSignal.title", fallback: "Signal strength is too low!")
    }
    public enum LowTemperature {
      /// Temperature is too low!
      public static let title = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.LowTemperature.title", fallback: "Temperature is too low!")
    }
    public enum Mute {
      /// Mute for an hour
      public static let button = RuuviLocalization.tr("Localizable", "LocalNotificationsManager.Mute.button", fallback: "Mute for an hour")
    }
  }
  public enum Menu {
    public enum BuyGateway {
      public enum Url {
        /// https://ruuvi.com/gateway?utm_campaign=app_ua&utm_medium=referral&utm_source=ios
        public static let ios = RuuviLocalization.tr("Localizable", "Menu.BuyGateway.URL.IOS", fallback: "https://ruuvi.com/gateway?utm_campaign=app_ua&utm_medium=referral&utm_source=ios")
      }
    }
    public enum Label {
      public enum AboutHelp {
        /// About / Help
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.AboutHelp.text", fallback: "About / Help")
      }
      public enum AddAnNewSensor {
        /// Add a New Sensor
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.AddAnNewSensor.text", fallback: "Add a New Sensor")
      }
      public enum AppSettings {
        /// App Settings
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.AppSettings.text", fallback: "App Settings")
      }
      public enum BuyRuuviGateway {
        /// Buy Ruuvi Gateway
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.BuyRuuviGateway.text", fallback: "Buy Ruuvi Gateway")
      }
      public enum Feedback {
        /// Send Feedback
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.Feedback.text", fallback: "Send Feedback")
      }
      public enum GetMoreSensors {
        /// Buy Ruuvi Sensors
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.GetMoreSensors.text", fallback: "Buy Ruuvi Sensors")
      }
      public enum MyRuuviAccount {
        /// My Ruuvi Account
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.MyRuuviAccount.text", fallback: "My Ruuvi Account")
      }
      public enum WhatToMeasure {
        /// What to measure with Ruuvi?
        public static let text = RuuviLocalization.tr("Localizable", "Menu.Label.WhatToMeasure.text", fallback: "What to measure with Ruuvi?")
      }
    }
    public enum LoggedIn {
      /// Signed in:
      public static let title = RuuviLocalization.tr("Localizable", "Menu.LoggedIn.title", fallback: "Signed in:")
    }
    public enum Measure {
      public enum Url {
        /// https://ruuvi.com/ideas?utm_campaign=app_ua&utm_medium=referral&utm_source=ios
        public static let ios = RuuviLocalization.tr("Localizable", "Menu.Measure.URL.IOS", fallback: "https://ruuvi.com/ideas?utm_campaign=app_ua&utm_medium=referral&utm_source=ios")
      }
    }
    public enum RuuviNetworkStatus {
      /// Ruuvi Cloud status
      public static let text = RuuviLocalization.tr("Localizable", "Menu.RuuviNetworkStatus.text", fallback: "Ruuvi Cloud status")
    }
    public enum SignOut {
      /// Sign out
      public static let text = RuuviLocalization.tr("Localizable", "Menu.SignOut.text", fallback: "Sign out")
    }
  }
  public enum MenuTableViewController {
    /// none
    public static let `none` = RuuviLocalization.tr("Localizable", "MenuTableViewController.None", fallback: "none")
    /// User: %@
    public static func user(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "MenuTableViewController.User", String(describing: p1), fallback: "User: %@")
    }
  }
  public enum MyRuuvi {
    public enum Settings {
      public enum DeleteAccount {
        /// Delete Account
        public static let title = RuuviLocalization.tr("Localizable", "MyRuuvi.Settings.DeleteAccount.title", fallback: "Delete Account")
        public enum Confirmation {
          /// A confirmation has been sent to your email. To proceed with the deletion, please check your inbox and follow the instructions.
          public static let message = RuuviLocalization.tr("Localizable", "MyRuuvi.Settings.DeleteAccount.Confirmation.message", fallback: "A confirmation has been sent to your email. To proceed with the deletion, please check your inbox and follow the instructions.")
        }
      }
    }
  }
  public enum OWMError {
    /// API limit exceeded
    public static let apiLimitExceeded = RuuviLocalization.tr("Localizable", "OWMError.apiLimitExceeded", fallback: "API limit exceeded")
    /// Failed to parse Open Weather Map response
    public static let failedToParseOpenWeatherMapResponse = RuuviLocalization.tr("Localizable", "OWMError.failedToParseOpenWeatherMapResponse", fallback: "Failed to parse Open Weather Map response")
    /// Invalid API Key
    public static let invalidApiKey = RuuviLocalization.tr("Localizable", "OWMError.invalidApiKey", fallback: "Invalid API Key")
    /// Not an HTTP response
    public static let notAHttpResponse = RuuviLocalization.tr("Localizable", "OWMError.notAHttpResponse", fallback: "Not an HTTP response")
  }
  public enum OffsetCorrection {
    public enum Calibrate {
      /// Offset correction
      public static let button = RuuviLocalization.tr("Localizable", "OffsetCorrection.Calibrate.button", fallback: "Offset correction")
    }
    public enum CalibrationDescription {
      /// In normal use, it's not necessary to adjust the offset.
      /// 
      /// If you're an advanced user and you'd like to manually configure the factory calibrated sensors, it's possible to do so.
      /// 
      /// Calibration tips are available on ruuvi.com/support
      public static let text = RuuviLocalization.tr("Localizable", "OffsetCorrection.CalibrationDescription.text", fallback: "In normal use, it's not necessary to adjust the offset.\n\nIf you're an advanced user and you'd like to manually configure the factory calibrated sensors, it's possible to do so.\n\nCalibration tips are available on ruuvi.com/support")
    }
    public enum CorrectedValue {
      /// Corrected value
      public static let title = RuuviLocalization.tr("Localizable", "OffsetCorrection.CorrectedValue.title", fallback: "Corrected value")
    }
    public enum Dialog {
      public enum Calibration {
        /// Clear calibration settings?
        public static let clearConfirm = RuuviLocalization.tr("Localizable", "OffsetCorrection.Dialog.Calibration.ClearConfirm", fallback: "Clear calibration settings?")
        /// Enter the expected humidity value from sensor under current conditions (%@): 
        public static func enterHumidity(_ p1: Any) -> String {
          return RuuviLocalization.tr("Localizable", "OffsetCorrection.Dialog.Calibration.EnterHumidity", String(describing: p1), fallback: "Enter the expected humidity value from sensor under current conditions (%@): ")
        }
        /// Enter the expected pressure value from sensor under current conditions (%@): 
        public static func enterPressure(_ p1: Any) -> String {
          return RuuviLocalization.tr("Localizable", "OffsetCorrection.Dialog.Calibration.EnterPressure", String(describing: p1), fallback: "Enter the expected pressure value from sensor under current conditions (%@): ")
        }
        /// Enter the expected temperature value from sensor under current conditions (%@): 
        public static func enterTemperature(_ p1: Any) -> String {
          return RuuviLocalization.tr("Localizable", "OffsetCorrection.Dialog.Calibration.EnterTemperature", String(describing: p1), fallback: "Enter the expected temperature value from sensor under current conditions (%@): ")
        }
        /// Calibration setup
        public static let title = RuuviLocalization.tr("Localizable", "OffsetCorrection.Dialog.Calibration.Title", fallback: "Calibration setup")
      }
    }
    public enum Humidity {
      /// Humidity offset
      public static let title = RuuviLocalization.tr("Localizable", "OffsetCorrection.Humidity.Title", fallback: "Humidity offset")
    }
    public enum OriginalValue {
      /// Original measured value
      public static let title = RuuviLocalization.tr("Localizable", "OffsetCorrection.OriginalValue.title", fallback: "Original measured value")
    }
    public enum Pressure {
      /// Pressure offset
      public static let title = RuuviLocalization.tr("Localizable", "OffsetCorrection.Pressure.Title", fallback: "Pressure offset")
    }
    public enum Temperature {
      /// Temperature offset
      public static let title = RuuviLocalization.tr("Localizable", "OffsetCorrection.Temperature.Title", fallback: "Temperature offset")
    }
  }
  public enum Owner {
    /// Claim sensor
    public static let title = RuuviLocalization.tr("Localizable", "Owner.title", fallback: "Claim sensor")
    public enum Claim {
      /// Do you own this sensor? If yes, please claim ownership of the sensor and it'll be added to your Ruuvi account. Each Ruuvi sensor can have only one owner. To claim ownership, you need to be signed in.
      /// 
      /// Benefits:
      /// 
      ///  ● Sensor names, background images, offsets and alert settings will be securely stored on the cloud
      /// 
      ///  ● Access sensors remotely over the Internet (requires a Ruuvi Gateway)
      /// 
      ///  ● Share sensors with friends and family (requires a Ruuvi Gateway)
      /// 
      ///  ● Browse up to 2 years of history on station.ruuvi.com (requires a Ruuvi Gateway)
      public static let description = RuuviLocalization.tr("Localizable", "Owner.Claim.description", fallback: "Do you own this sensor? If yes, please claim ownership of the sensor and it'll be added to your Ruuvi account. Each Ruuvi sensor can have only one owner. To claim ownership, you need to be signed in.\n\nBenefits:\n\n ● Sensor names, background images, offsets and alert settings will be securely stored on the cloud\n\n ● Access sensors remotely over the Internet (requires a Ruuvi Gateway)\n\n ● Share sensors with friends and family (requires a Ruuvi Gateway)\n\n ● Browse up to 2 years of history on station.ruuvi.com (requires a Ruuvi Gateway)")
    }
    public enum ClaimOwnership {
      /// Claim ownership
      public static let button = RuuviLocalization.tr("Localizable", "Owner.ClaimOwnership.button", fallback: "Claim ownership")
    }
  }
  public enum PermissionPresenter {
    /// Settings
    public static let settings = RuuviLocalization.tr("Localizable", "PermissionPresenter.settings", fallback: "Settings")
    public enum NoCameraAccess {
      /// Ruuvi Station needs to access your camera to enable this feature.
      public static let message = RuuviLocalization.tr("Localizable", "PermissionPresenter.NoCameraAccess.message", fallback: "Ruuvi Station needs to access your camera to enable this feature.")
    }
    public enum NoLocationAccess {
      /// Ruuvi Station needs to access your location to enable this feature.
      public static let message = RuuviLocalization.tr("Localizable", "PermissionPresenter.NoLocationAccess.message", fallback: "Ruuvi Station needs to access your location to enable this feature.")
    }
    public enum NoPhotoLibraryAccess {
      /// Ruuvi Station needs to access your camera library to enable this feature.
      public static let message = RuuviLocalization.tr("Localizable", "PermissionPresenter.NoPhotoLibraryAccess.message", fallback: "Ruuvi Station needs to access your camera library to enable this feature.")
    }
    public enum NoPushNotificationsPermission {
      /// Ruuvi Station needs push notifications permission to enable this feature
      public static let message = RuuviLocalization.tr("Localizable", "PermissionPresenter.NoPushNotificationsPermission.message", fallback: "Ruuvi Station needs push notifications permission to enable this feature")
    }
  }
  public enum PhotoPicker {
    public enum Sheet {
      /// Take photo
      public static let camera = RuuviLocalization.tr("Localizable", "PhotoPicker.Sheet.camera", fallback: "Take photo")
      /// Choose from files
      public static let files = RuuviLocalization.tr("Localizable", "PhotoPicker.Sheet.files", fallback: "Choose from files")
      /// Choose from the library
      public static let library = RuuviLocalization.tr("Localizable", "PhotoPicker.Sheet.library", fallback: "Choose from the library")
      /// Pick a photo
      public static let message = RuuviLocalization.tr("Localizable", "PhotoPicker.Sheet.message", fallback: "Pick a photo")
    }
  }
  public enum Ruuvi {
    public enum BuySensors {
      public enum Menu {
        public enum Url {
          /// https://ruuvi.com/products?utm_campaign=app_ua_nav&utm_medium=referral&utm_source=ios
          public static let ios = RuuviLocalization.tr("Localizable", "Ruuvi.BuySensors.Menu.URL.IOS", fallback: "https://ruuvi.com/products?utm_campaign=app_ua_nav&utm_medium=referral&utm_source=ios")
        }
      }
      public enum Url {
        /// https://ruuvi.com/products?utm_campaign=app_ua&utm_medium=referral&utm_source=ios
        public static let ios = RuuviLocalization.tr("Localizable", "Ruuvi.BuySensors.URL.IOS", fallback: "https://ruuvi.com/products?utm_campaign=app_ua&utm_medium=referral&utm_source=ios")
      }
    }
  }
  public enum RuuviCloudApiError {
    /// Empty response
    public static let emptyResponse = RuuviLocalization.tr("Localizable", "RuuviCloudApiError.emptyResponse", fallback: "Empty response")
    /// Failed to get data from response
    public static let failedToGetDataFromResponse = RuuviLocalization.tr("Localizable", "RuuviCloudApiError.failedToGetDataFromResponse", fallback: "Failed to get data from response")
    /// Unexpected HTTP status code
    public static let unexpectedHTTPStatusCode = RuuviLocalization.tr("Localizable", "RuuviCloudApiError.unexpectedHTTPStatusCode", fallback: "Unexpected HTTP status code")
  }
  public enum RuuviCloudError {
    /// Not authorised
    public static let notAuthorized = RuuviLocalization.tr("Localizable", "RuuviCloudError.NotAuthorized", fallback: "Not authorised")
  }
  public enum RuuviDfuError {
    /// Failed to construct UUID
    public static let failedToConstructUUID = RuuviLocalization.tr("Localizable", "RuuviDfuError.failedToConstructUUID", fallback: "Failed to construct UUID")
    /// Invalid firmware file
    public static let invalidFirmwareFile = RuuviLocalization.tr("Localizable", "RuuviDfuError.invalidFirmwareFile", fallback: "Invalid firmware file")
  }
  public enum RuuviLocalError {
    /// Failed to get background directory
    public static let failedToGetDocumentsDirectory = RuuviLocalization.tr("Localizable", "RuuviLocalError.failedToGetDocumentsDirectory", fallback: "Failed to get background directory")
    /// Failed to get JPG representation
    public static let failedToGetJpegRepresentation = RuuviLocalization.tr("Localizable", "RuuviLocalError.failedToGetJpegRepresentation", fallback: "Failed to get JPG representation")
  }
  public enum RuuviOnboard {
    public enum Access {
      /// Access data for each linked sensor in real time and explore history graphs.
      public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Access.title", fallback: "Access data for each linked sensor in real time and explore history graphs.")
    }
    public enum Alerts {
      /// Set alerts and get notified whenever your limits are hit.
      public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Alerts.title", fallback: "Set alerts and get notified whenever your limits are hit.")
    }
    public enum Cloud {
      /// Claim ownership of your sensors with a free Ruuvi Cloud account.
      public static let subtitle = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.subtitle", fallback: "Claim ownership of your sensors with a free Ruuvi Cloud account.")
      /// Sign in to use the full potential of the app.
      public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.title", fallback: "Sign in to use the full potential of the app.")
      public enum Benefits {
        /// Benefits:
        /// 
        ///  ● Sensor names, background images, offsets and alert settings will be securely stored on the cloud
        /// 
        ///  ● Access sensors remotely over the Internet (requires a Ruuvi Gateway)
        /// 
        ///  ● Share sensors with friends and family (requires a Ruuvi Gateway)
        /// 
        ///  ● Browse up to 2 years of history on station.ruuvi.com (requires a Ruuvi Gateway)
        public static let message = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.Benefits.message", fallback: "Benefits:\n\n ● Sensor names, background images, offsets and alert settings will be securely stored on the cloud\n\n ● Access sensors remotely over the Internet (requires a Ruuvi Gateway)\n\n ● Share sensors with friends and family (requires a Ruuvi Gateway)\n\n ● Browse up to 2 years of history on station.ruuvi.com (requires a Ruuvi Gateway)")
      }
      public enum Details {
        /// Details
        public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.Details.title", fallback: "Details")
      }
      public enum Skip {
        /// Are you sure you want to skip sign in?
        public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.Skip.title", fallback: "Are you sure you want to skip sign in?")
        public enum GoBack {
          /// Go back
          public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.Skip.GoBack.title", fallback: "Go back")
        }
        public enum Yes {
          /// Yes, skip
          public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.Skip.Yes.title", fallback: "Yes, skip")
        }
      }
      public enum Subtitle {
        /// Great! You already signed in!
        public static let signed = RuuviLocalization.tr("Localizable", "RuuviOnboard.Cloud.subtitle.signed", fallback: "Great! You already signed in!")
      }
    }
    public enum Measure {
      /// Measure environmental data: temperature, relative humidity and air pressure.
      public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Measure.title", fallback: "Measure environmental data: temperature, relative humidity and air pressure.")
    }
    public enum Start {
      /// Press SCAN to find and add nearby sensors to your Ruuvi Station.
      public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Start.title", fallback: "Press SCAN to find and add nearby sensors to your Ruuvi Station.")
    }
    public enum Welcome {
      /// Swipe to see what Ruuvi Station can do for you.
      public static let title = RuuviLocalization.tr("Localizable", "RuuviOnboard.Welcome.title", fallback: "Swipe to see what Ruuvi Station can do for you.")
    }
  }
  public enum RuuviPersistenceError {
    /// Failed to find sensor
    public static let failedToFindRuuviTag = RuuviLocalization.tr("Localizable", "RuuviPersistenceError.failedToFindRuuviTag", fallback: "Failed to find sensor")
  }
  public enum RuuviServiceError {
    /// Both local and MAC identifiers are nil
    public static let bothLuidAndMacAreNil = RuuviLocalization.tr("Localizable", "RuuviServiceError.bothLuidAndMacAreNil", fallback: "Both local and MAC identifiers are nil")
    /// Failed to find or generate background image
    public static let failedToFindOrGenerateBackgroundImage = RuuviLocalization.tr("Localizable", "RuuviServiceError.failedToFindOrGenerateBackgroundImage", fallback: "Failed to find or generate background image")
    /// Failed to get JPG representation
    public static let failedToGetJpegRepresentation = RuuviLocalization.tr("Localizable", "RuuviServiceError.failedToGetJpegRepresentation", fallback: "Failed to get JPG representation")
    /// Failed to parse response.
    public static let failedToParseNetworkResponse = RuuviLocalization.tr("Localizable", "RuuviServiceError.failedToParseNetworkResponse", fallback: "Failed to parse response.")
    /// MAC identifier is nil
    public static let macIdIsNil = RuuviLocalization.tr("Localizable", "RuuviServiceError.macIdIsNil", fallback: "MAC identifier is nil")
    /// Photo URL is nil
    public static let pictureUrlIsNil = RuuviLocalization.tr("Localizable", "RuuviServiceError.pictureUrlIsNil", fallback: "Photo URL is nil")
  }
  public enum Settings {
    public enum BackgroundScanning {
      /// Data logging interval
      public static let interval = RuuviLocalization.tr("Localizable", "Settings.BackgroundScanning.interval", fallback: "Data logging interval")
      /// Background Scanning
      public static let title = RuuviLocalization.tr("Localizable", "Settings.BackgroundScanning.title", fallback: "Background Scanning")
      public enum Footer {
        /// Important note: Bluetooth background history logging and Bluetooth alerts work only when background scanning is enabled. If you disable the background scanning, all paired Ruuvi sensors will be automatically unpaired and you need to pair them again from their settings pages.
        public static let message = RuuviLocalization.tr("Localizable", "Settings.BackgroundScanning.Footer.message", fallback: "Important note: Bluetooth background history logging and Bluetooth alerts work only when background scanning is enabled. If you disable the background scanning, all paired Ruuvi sensors will be automatically unpaired and you need to pair them again from their settings pages.")
      }
    }
    public enum ChooseHumidityUnit {
      /// Choose the humidity unit you want to be displayed.
      public static let text = RuuviLocalization.tr("Localizable", "Settings.ChooseHumidityUnit.text", fallback: "Choose the humidity unit you want to be displayed.")
    }
    public enum ChoosePressureUnit {
      /// Choose the pressure unit you want to be displayed.
      public static let text = RuuviLocalization.tr("Localizable", "Settings.ChoosePressureUnit.text", fallback: "Choose the pressure unit you want to be displayed.")
    }
    public enum ChooseTemperatureUnit {
      /// Choose the temperature unit you want to be displayed.
      public static let text = RuuviLocalization.tr("Localizable", "Settings.ChooseTemperatureUnit.text", fallback: "Choose the temperature unit you want to be displayed.")
    }
    public enum Humidity {
      public enum Resolution {
        /// Humidity Resolution
        public static let title = RuuviLocalization.tr("Localizable", "Settings.Humidity.Resolution.title", fallback: "Humidity Resolution")
      }
    }
    public enum Label {
      /// Chart Settings
      public static let chart = RuuviLocalization.tr("Localizable", "Settings.Label.Chart", fallback: "Chart Settings")
      /// Cloud mode
      public static let cloudMode = RuuviLocalization.tr("Localizable", "Settings.Label.CloudMode", fallback: "Cloud mode")
      /// Defaults
      public static let defaults = RuuviLocalization.tr("Localizable", "Settings.Label.Defaults", fallback: "Defaults")
      /// Foreground
      public static let foreground = RuuviLocalization.tr("Localizable", "Settings.Label.Foreground", fallback: "Foreground")
      /// Humidity
      public static let humidity = RuuviLocalization.tr("Localizable", "Settings.Label.Humidity", fallback: "Humidity")
      /// Pressure
      public static let pressure = RuuviLocalization.tr("Localizable", "Settings.Label.Pressure", fallback: "Pressure")
      /// Temperature
      public static let temperature = RuuviLocalization.tr("Localizable", "Settings.Label.Temperature", fallback: "Temperature")
      public enum CloudMode {
        /// Refresh nearby cloud sensors only from the cloud by ignoring their Bluetooth messages and receiving alerts only by email. Requires a Ruuvi Gateway router.
        public static let description = RuuviLocalization.tr("Localizable", "Settings.Label.CloudMode.description", fallback: "Refresh nearby cloud sensors only from the cloud by ignoring their Bluetooth messages and receiving alerts only by email. Requires a Ruuvi Gateway router.")
      }
      public enum HumidityUnit {
        /// Humidity Unit
        public static let text = RuuviLocalization.tr("Localizable", "Settings.Label.HumidityUnit.text", fallback: "Humidity Unit")
      }
      public enum Language {
        /// Language
        public static let text = RuuviLocalization.tr("Localizable", "Settings.Label.Language.text", fallback: "Language")
      }
      public enum PressureUnit {
        /// Pressure Unit
        public static let text = RuuviLocalization.tr("Localizable", "Settings.Label.PressureUnit.text", fallback: "Pressure Unit")
      }
      public enum TemperatureUnit {
        /// Temperature Unit
        public static let text = RuuviLocalization.tr("Localizable", "Settings.Label.TemperatureUnit.text", fallback: "Temperature Unit")
      }
    }
    public enum Language {
      public enum Dialog {
        /// Open settings and tap Language to change language of the app.
        /// If you cannot see the Language option in the settings, make sure that you have at least one preferred language added in system settings: Settings -> General -> Language & Region.
        public static let message = RuuviLocalization.tr("Localizable", "Settings.Language.Dialog.message", fallback: "Open settings and tap Language to change language of the app.\nIf you cannot see the Language option in the settings, make sure that you have at least one preferred language added in system settings: Settings -> General -> Language & Region.")
        /// Select Language
        public static let title = RuuviLocalization.tr("Localizable", "Settings.Language.Dialog.title", fallback: "Select Language")
      }
    }
    public enum Measurement {
      public enum Resolution {
        /// Select how accurately you'd like to see the sensors' live measurement values in the app. This setting doesn't affect history charts or alerts.
        public static let description = RuuviLocalization.tr("Localizable", "Settings.Measurement.Resolution.description", fallback: "Select how accurately you'd like to see the sensors' live measurement values in the app. This setting doesn't affect history charts or alerts.")
        /// Resolution
        public static let title = RuuviLocalization.tr("Localizable", "Settings.Measurement.Resolution.title", fallback: "Resolution")
      }
      public enum Unit {
        /// Unit
        public static let title = RuuviLocalization.tr("Localizable", "Settings.Measurement.Unit.title", fallback: "Unit")
      }
    }
    public enum Pressure {
      public enum Resolution {
        /// Pressure Resolution
        public static let title = RuuviLocalization.tr("Localizable", "Settings.Pressure.Resolution.title", fallback: "Pressure Resolution")
      }
    }
    public enum SectionHeader {
      public enum Application {
        /// APPLICATION
        public static let title = RuuviLocalization.tr("Localizable", "Settings.SectionHeader.Application.title", fallback: "APPLICATION")
      }
      public enum General {
        /// GENERAL
        public static let title = RuuviLocalization.tr("Localizable", "Settings.SectionHeader.General.title", fallback: "GENERAL")
      }
    }
    public enum SegmentedControl {
      public enum Humidity {
        public enum Absolute {
          /// Abs
          public static let title = RuuviLocalization.tr("Localizable", "Settings.SegmentedControl.Humidity.Absolute.title", fallback: "Abs")
        }
        public enum DewPoint {
          /// Dew
          public static let title = RuuviLocalization.tr("Localizable", "Settings.SegmentedControl.Humidity.DewPoint.title", fallback: "Dew")
        }
        public enum Relative {
          /// Rel
          public static let title = RuuviLocalization.tr("Localizable", "Settings.SegmentedControl.Humidity.Relative.title", fallback: "Rel")
        }
      }
    }
    public enum Temperature {
      public enum Resolution {
        /// Temperature Resolution
        public static let title = RuuviLocalization.tr("Localizable", "Settings.Temperature.Resolution.title", fallback: "Temperature Resolution")
      }
    }
    public enum NavigationItem {
      /// Settings
      public static let title = RuuviLocalization.tr("Localizable", "Settings.navigationItem.title", fallback: "Settings")
    }
  }
  public enum Share {
    public enum Send {
      /// Send
      public static let button = RuuviLocalization.tr("Localizable", "Share.Send.button", fallback: "Send")
    }
    public enum Success {
      /// Successfully shared sensor
      public static let message = RuuviLocalization.tr("Localizable", "Share.Success.message", fallback: "Successfully shared sensor")
    }
  }
  public enum SharePresenter {
    public enum UnshareSensor {
      /// Do you want to unshare sensor for %@?
      public static func message(_ p1: Any) -> String {
        return RuuviLocalization.tr("Localizable", "SharePresenter.UnshareSensor.Message", String(describing: p1), fallback: "Do you want to unshare sensor for %@?")
      }
    }
  }
  public enum ShareViewController {
    /// You can share the sensor with friends and family if it's in range of a Ruuvi Gateway.
    /// 
    /// Receiver will be notified by email. If the receiver doesn't have a Ruuvi account, a free Ruuvi account will automatically be created at first log in.
    /// 
    /// Note that the sensor's custom name and background image will be shared. The name and image sync is one time only, and after this, they can be privately customised by the receiver. Offset values (if any) set by the owner, will be automatically synced, and the receiver will always see the final corrected values.
    public static let description = RuuviLocalization.tr("Localizable", "ShareViewController.Description", fallback: "You can share the sensor with friends and family if it's in range of a Ruuvi Gateway.\n\nReceiver will be notified by email. If the receiver doesn't have a Ruuvi account, a free Ruuvi account will automatically be created at first log in.\n\nNote that the sensor's custom name and background image will be shared. The name and image sync is one time only, and after this, they can be privately customised by the receiver. Offset values (if any) set by the owner, will be automatically synced, and the receiver will always see the final corrected values.")
    /// Share sensor
    public static let title = RuuviLocalization.tr("Localizable", "ShareViewController.Title", fallback: "Share sensor")
    public enum AddFriend {
      /// Add friend
      public static let title = RuuviLocalization.tr("Localizable", "ShareViewController.addFriend.Title", fallback: "Add friend")
    }
    public enum EmailTextField {
      /// Type email
      public static let placeholder = RuuviLocalization.tr("Localizable", "ShareViewController.emailTextField.placeholder", fallback: "Type email")
    }
    public enum SharedEmails {
      /// You have used %d/%d of maximum shares of this sensor. The sensor has been shared to following users:
      public static func title(_ p1: Int, _ p2: Int) -> String {
        return RuuviLocalization.tr("Localizable", "ShareViewController.sharedEmails.Title", p1, p2, fallback: "You have used %d/%d of maximum shares of this sensor. The sensor has been shared to following users:")
      }
    }
  }
  public enum SignIn {
    /// We've sent a one-time password to your email %@. Sign in by entering it here:
    public static func checkMailbox(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "SignIn.CheckMailbox", String(describing: p1), fallback: "We've sent a one-time password to your email %@. Sign in by entering it here:")
    }
    /// Code
    public static let codeHint = RuuviLocalization.tr("Localizable", "SignIn.CodeHint", fallback: "Code")
    /// Email
    public static let emailPlaceholder = RuuviLocalization.tr("Localizable", "SignIn.EmailPlaceholder", fallback: "Email")
    /// Email sent
    public static let emailSent = RuuviLocalization.tr("Localizable", "SignIn.EmailSent", fallback: "Email sent")
    /// Please enter verification code
    public static let enterVerificationCode = RuuviLocalization.tr("Localizable", "SignIn.EnterVerificationCode", fallback: "Please enter verification code")
    /// Request a code
    public static let requestCode = RuuviLocalization.tr("Localizable", "SignIn.RequestCode", fallback: "Request a code")
    /// Submit
    public static let submitCode = RuuviLocalization.tr("Localizable", "SignIn.SubmitCode", fallback: "Submit")
    /// verification code in format: CJSM
    public static let verificationCodePlaceholder = RuuviLocalization.tr("Localizable", "SignIn.VerificationCodePlaceholder", fallback: "verification code in format: CJSM")
    public enum EmailMismatch {
      public enum Alert {
        /// Oops, you've requested the code for %@, but used the code for %@. Please double check that you are using the code for %@
        public static func message(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
          return RuuviLocalization.tr("Localizable", "SignIn.EmailMismatch.Alert.message", String(describing: p1), String(describing: p2), String(describing: p3), fallback: "Oops, you've requested the code for %@, but used the code for %@. Please double check that you are using the code for %@")
        }
      }
    }
    public enum EmailMissing {
      public enum Alert {
        /// Oops, the email you've used to get the code was not saved. Please try to sign in again.
        public static let message = RuuviLocalization.tr("Localizable", "SignIn.EmailMissing.Alert.message", fallback: "Oops, the email you've used to get the code was not saved. Please try to sign in again.")
      }
    }
    public enum SubtitleLabel {
      /// To enjoy all the features, create a free account or sign in to your existing Ruuvi account by entering your email address.
      public static let text = RuuviLocalization.tr("Localizable", "SignIn.SubtitleLabel.text", fallback: "To enjoy all the features, create a free account or sign in to your existing Ruuvi account by entering your email address.")
    }
    public enum Sync {
      /// Downloading content from the cloud. Please wait.
      public static let message = RuuviLocalization.tr("Localizable", "SignIn.Sync.message", fallback: "Downloading content from the cloud. Please wait.")
    }
    public enum Title {
      /// Sign in
      public static let text = RuuviLocalization.tr("Localizable", "SignIn.Title.text", fallback: "Sign in")
    }
    public enum TitleLabel {
      /// Sign in to
      /// Ruuvi
      /// Station
      public static let text = RuuviLocalization.tr("Localizable", "SignIn.TitleLabel.text", fallback: "Sign in to\nRuuvi\nStation")
    }
  }
  public enum TagCharts {
    public enum AbortSync {
      public enum Alert {
        /// Sometimes the history download is slow due to the Bluetooth connectivity. Please wait a moment.
        public static let message = RuuviLocalization.tr("Localizable", "TagCharts.AbortSync.Alert.message", fallback: "Sometimes the history download is slow due to the Bluetooth connectivity. Please wait a moment.")
      }
      public enum Button {
        /// Abort download
        public static let title = RuuviLocalization.tr("Localizable", "TagCharts.AbortSync.Button.title", fallback: "Abort download")
      }
    }
    public enum BluetoothDisabledAlert {
      /// Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.
      public static let message = RuuviLocalization.tr("Localizable", "TagCharts.BluetoothDisabledAlert.message", fallback: "Ruuvi Station needs Bluetooth to be able to listen for sensors. Go to Settings and turn Bluetooth on.")
      /// Bluetooth is not enabled
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.BluetoothDisabledAlert.title", fallback: "Bluetooth is not enabled")
    }
    public enum Clear {
      /// Clear
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.Clear.title", fallback: "Clear")
    }
    public enum DeleteHistoryConfirmationDialog {
      /// Clear the local history data from the app?
      public static let message = RuuviLocalization.tr("Localizable", "TagCharts.DeleteHistoryConfirmationDialog.message", fallback: "Clear the local history data from the app?")
      /// Are you sure?
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.DeleteHistoryConfirmationDialog.title", fallback: "Are you sure?")
      public enum Button {
        public enum Delete {
          /// Delete
          public static let title = RuuviLocalization.tr("Localizable", "TagCharts.DeleteHistoryConfirmationDialog.button.delete.title", fallback: "Delete")
        }
      }
    }
    public enum Dismiss {
      public enum Alert {
        /// The history download via Bluetooth connection is in progress. Please wait.
        public static let message = RuuviLocalization.tr("Localizable", "TagCharts.Dismiss.Alert.message", fallback: "The history download via Bluetooth connection is in progress. Please wait.")
      }
    }
    public enum Export {
      /// EXPORT
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.Export.title", fallback: "EXPORT")
    }
    public enum FailedToSyncDialog {
      /// Bluetooth history download failed. Check that you're within Bluetooth range, your sensor has firmware that supports downloading and that the sensor is not simultaneously connected to another iOS device. Sensor connection is reserved for Ruuvi Station when using connected mode in iOS.
      public static let message = RuuviLocalization.tr("Localizable", "TagCharts.FailedToSyncDialog.message", fallback: "Bluetooth history download failed. Check that you're within Bluetooth range, your sensor has firmware that supports downloading and that the sensor is not simultaneously connected to another iOS device. Sensor connection is reserved for Ruuvi Station when using connected mode in iOS.")
      /// Download failed
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.FailedToSyncDialog.title", fallback: "Download failed")
    }
    public enum NoChartData {
      /// No chart data available
      public static let text = RuuviLocalization.tr("Localizable", "TagCharts.NoChartData.text", fallback: "No chart data available")
    }
    public enum Status {
      /// Connecting...
      public static let connecting = RuuviLocalization.tr("Localizable", "TagCharts.Status.Connecting", fallback: "Connecting...")
      /// Disconnecting...
      public static let disconnecting = RuuviLocalization.tr("Localizable", "TagCharts.Status.Disconnecting", fallback: "Disconnecting...")
      /// Error
      public static let error = RuuviLocalization.tr("Localizable", "TagCharts.Status.Error", fallback: "Error")
      /// Reading history
      public static let readingHistory = RuuviLocalization.tr("Localizable", "TagCharts.Status.ReadingHistory", fallback: "Reading history")
      /// Synchronising...
      public static let serving = RuuviLocalization.tr("Localizable", "TagCharts.Status.Serving", fallback: "Synchronising...")
      /// Success
      public static let success = RuuviLocalization.tr("Localizable", "TagCharts.Status.Success", fallback: "Success")
    }
    public enum Sync {
      /// Sync
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.Sync.title", fallback: "Sync")
    }
    public enum SyncConfirmationDialog {
      /// Download history data from the sensor?
      public static let message = RuuviLocalization.tr("Localizable", "TagCharts.SyncConfirmationDialog.message", fallback: "Download history data from the sensor?")
      /// Are you sure?
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.SyncConfirmationDialog.title", fallback: "Are you sure?")
    }
    public enum TryAgain {
      /// Try again
      public static let title = RuuviLocalization.tr("Localizable", "TagCharts.TryAgain.title", fallback: "Try again")
    }
  }
  public enum TagChartsPresenter {
    /// Synchronised: %@
    public static func numberOfPointsSynchronizedOverNetwork(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "TagChartsPresenter.NumberOfPointsSynchronizedOverNetwork", String(describing: p1), fallback: "Synchronised: %@")
    }
  }
  public enum TagSettings {
    /// Share
    public static let shareButton = RuuviLocalization.tr("Localizable", "TagSettings.ShareButton", fallback: "Share")
    public enum AirHumidityAlert {
      /// Air Humidity (%@)
      public static func title(_ p1: Any) -> String {
        return RuuviLocalization.tr("Localizable", "TagSettings.AirHumidityAlert.title", String(describing: p1), fallback: "Air Humidity (%@)")
      }
    }
    public enum Alert {
      public enum CustomDescription {
        /// Set custom description...
        public static let placeholder = RuuviLocalization.tr("Localizable", "TagSettings.Alert.CustomDescription.placeholder", fallback: "Set custom description...")
        /// Alert custom description
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Alert.CustomDescription.title", fallback: "Alert custom description")
      }
      public enum SetHumidity {
        /// Set humidity alert
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Alert.SetHumidity.title", fallback: "Set humidity alert")
      }
      public enum SetPressure {
        /// Set pressure alert
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Alert.SetPressure.title", fallback: "Set pressure alert")
      }
      public enum SetRSSI {
        /// Set signal strength alert
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Alert.SetRSSI.title", fallback: "Set signal strength alert")
      }
      public enum SetTemperature {
        /// Set temperature alert
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Alert.SetTemperature.title", fallback: "Set temperature alert")
      }
    }
    public enum AlertSettings {
      public enum Dialog {
        /// Max (%0.f)
        public static let max = RuuviLocalization.tr("Localizable", "TagSettings.AlertSettings.Dialog.Max", fallback: "Max (%0.f)")
        /// Min (%0.f)
        public static let min = RuuviLocalization.tr("Localizable", "TagSettings.AlertSettings.Dialog.Min", fallback: "Min (%0.f)")
      }
    }
    public enum Alerts {
      /// Off
      public static let off = RuuviLocalization.tr("Localizable", "TagSettings.Alerts.Off", fallback: "Off")
      public enum Connection {
        /// Alert when connected/disconnected
        public static let description = RuuviLocalization.tr("Localizable", "TagSettings.Alerts.Connection.description", fallback: "Alert when connected/disconnected")
      }
      public enum DewPoint {
        /// Alert when less than %.0f or more than %.0f
        public static func description(_ p1: Float, _ p2: Float) -> String {
          return RuuviLocalization.tr("Localizable", "TagSettings.Alerts.DewPoint.description", p1, p2, fallback: "Alert when less than %.0f or more than %.0f")
        }
      }
      public enum Humidity {
        /// Alert when less than %.0f or more than %.0f
        public static func description(_ p1: Float, _ p2: Float) -> String {
          return RuuviLocalization.tr("Localizable", "TagSettings.Alerts.Humidity.description", p1, p2, fallback: "Alert when less than %.0f or more than %.0f")
        }
      }
      public enum Movement {
        /// Alert when sensor is moved
        public static let description = RuuviLocalization.tr("Localizable", "TagSettings.Alerts.Movement.description", fallback: "Alert when sensor is moved")
      }
      public enum Pressure {
        /// Alert when less than %.0f or more than %.0f
        public static func description(_ p1: Float, _ p2: Float) -> String {
          return RuuviLocalization.tr("Localizable", "TagSettings.Alerts.Pressure.description", p1, p2, fallback: "Alert when less than %.0f or more than %.0f")
        }
      }
      public enum Temperature {
        /// Alert when less than %0.f or more than %0.f
        public static let description = RuuviLocalization.tr("Localizable", "TagSettings.Alerts.Temperature.description", fallback: "Alert when less than %0.f or more than %0.f")
      }
    }
    public enum AlertsAreDisabled {
      public enum Dialog {
        public enum BothNotConnectedAndNoPNPermission {
          /// Alerts are disabled because the device is not connected and missing push notification permission. Please connect to the device first.
          public static let message = RuuviLocalization.tr("Localizable", "TagSettings.AlertsAreDisabled.Dialog.BothNotConnectedAndNoPNPermission.message", fallback: "Alerts are disabled because the device is not connected and missing push notification permission. Please connect to the device first.")
        }
        public enum Connect {
          /// Connect
          public static let title = RuuviLocalization.tr("Localizable", "TagSettings.AlertsAreDisabled.Dialog.Connect.title", fallback: "Connect")
        }
        public enum NotConnected {
          /// Alerts are disabled because you are not connected to the device.
          public static let message = RuuviLocalization.tr("Localizable", "TagSettings.AlertsAreDisabled.Dialog.NotConnected.message", fallback: "Alerts are disabled because you are not connected to the device.")
        }
      }
    }
    public enum BatteryStatusLabel {
      public enum Ok {
        /// Battery OK
        public static let message = RuuviLocalization.tr("Localizable", "TagSettings.BatteryStatusLabel.Ok.message", fallback: "Battery OK")
      }
      public enum Replace {
        /// Low battery
        public static let message = RuuviLocalization.tr("Localizable", "TagSettings.BatteryStatusLabel.Replace.message", fallback: "Low battery")
      }
    }
    public enum ClaimTagButton {
      /// Claim ownership
      public static let claim = RuuviLocalization.tr("Localizable", "TagSettings.ClaimTagButton.Claim", fallback: "Claim ownership")
    }
    public enum ConnectStatus {
      /// Disconnected
      public static let disconnected = RuuviLocalization.tr("Localizable", "TagSettings.ConnectStatus.Disconnected", fallback: "Disconnected")
    }
    public enum ConnectionAlert {
      /// Connection
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.ConnectionAlert.title", fallback: "Connection")
    }
    public enum DataSource {
      public enum Advertisement {
        /// Advertisement
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.DataSource.Advertisement.title", fallback: "Advertisement")
      }
      public enum Heartbeat {
        /// Heartbeat
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.DataSource.Heartbeat.title", fallback: "Heartbeat")
      }
      public enum Network {
        /// Cloud
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.DataSource.Network.title", fallback: "Cloud")
      }
    }
    public enum EmptyValue {
      /// -
      public static let sign = RuuviLocalization.tr("Localizable", "TagSettings.EmptyValue.sign", fallback: "-")
    }
    public enum Firmware {
      /// Current version
      public static let currentVersion = RuuviLocalization.tr("Localizable", "TagSettings.Firmware.CurrentVersion", fallback: "Current version")
      /// Update
      public static let updateFirmware = RuuviLocalization.tr("Localizable", "TagSettings.Firmware.UpdateFirmware", fallback: "Update")
      public enum CurrentVersion {
        /// Very old
        public static let veryOld = RuuviLocalization.tr("Localizable", "TagSettings.Firmware.CurrentVersion.VeryOld", fallback: "Very old")
      }
    }
    public enum General {
      public enum Owner {
        /// No owner
        public static let `none` = RuuviLocalization.tr("Localizable", "TagSettings.General.Owner.none", fallback: "No owner")
      }
    }
    public enum HumidityIsClipped {
      public enum Alert {
        /// Humidity value is greater than 100% after calibration. This value doesn't make sense, so the value has been adjusted to 100%.
        public static func message(_ p1: Float) -> String {
          return RuuviLocalization.tr("Localizable", "TagSettings.HumidityIsClipped.Alert.message", p1, fallback: "Humidity value is greater than 100% after calibration. This value doesn't make sense, so the value has been adjusted to 100%.")
        }
        /// Humidity is adjusted
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.HumidityIsClipped.Alert.title", fallback: "Humidity is adjusted")
        public enum Fix {
          /// Fix
          public static let button = RuuviLocalization.tr("Localizable", "TagSettings.HumidityIsClipped.Alert.Fix.button", fallback: "Fix")
        }
      }
    }
    public enum Label {
      public enum Alerts {
        /// Alerts
        public static let text = RuuviLocalization.tr("Localizable", "TagSettings.Label.alerts.text", fallback: "Alerts")
      }
      public enum Disabled {
        /// DISABLED?
        public static let text = RuuviLocalization.tr("Localizable", "TagSettings.Label.disabled.text", fallback: "DISABLED?")
      }
      public enum MoreInfo {
        /// More info
        public static let text = RuuviLocalization.tr("Localizable", "TagSettings.Label.moreInfo.text", fallback: "More info")
      }
      public enum NoValues {
        /// NO VALUES?
        public static let text = RuuviLocalization.tr("Localizable", "TagSettings.Label.noValues.text", fallback: "NO VALUES?")
      }
    }
    public enum Mac {
      public enum Alert {
        /// MAC Address
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Mac.Alert.title", fallback: "MAC Address")
      }
    }
    public enum MovementAlert {
      /// Movement
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.MovementAlert.title", fallback: "Movement")
    }
    public enum NetworkInfo {
      /// Owner
      public static let owner = RuuviLocalization.tr("Localizable", "TagSettings.NetworkInfo.Owner", fallback: "Owner")
    }
    public enum NotShared {
      /// Not shared
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.NotShared.title", fallback: "Not shared")
    }
    public enum OffsetCorrection {
      /// Humidity
      public static let humidity = RuuviLocalization.tr("Localizable", "TagSettings.OffsetCorrection.Humidity", fallback: "Humidity")
      /// Pressure
      public static let pressure = RuuviLocalization.tr("Localizable", "TagSettings.OffsetCorrection.Pressure", fallback: "Pressure")
      /// Temperature
      public static let temperature = RuuviLocalization.tr("Localizable", "TagSettings.OffsetCorrection.Temperature", fallback: "Temperature")
    }
    public enum PairAndBackgroundScan {
      /// Alerts are not available over Bluetooth connection if background scanning is not enabled. Only one iOS device can be paired to a Ruuvi sensor at a time.
      public static let description = RuuviLocalization.tr("Localizable", "TagSettings.PairAndBackgroundScan.description", fallback: "Alerts are not available over Bluetooth connection if background scanning is not enabled. Only one iOS device can be paired to a Ruuvi sensor at a time.")
      public enum Paired {
        /// Paired and background scan is on
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.PairAndBackgroundScan.Paired.title", fallback: "Paired and background scan is on")
      }
      public enum Pairing {
        /// Connecting to the sensor
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.PairAndBackgroundScan.Pairing.title", fallback: "Connecting to the sensor")
      }
      public enum Unpaired {
        /// Pair and use background scan
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.PairAndBackgroundScan.Unpaired.title", fallback: "Pair and use background scan")
      }
    }
    public enum PairError {
      public enum CloudMode {
        /// The sensor cannot be connected to via Bluetooth when the cloud mode is active. You can re-enable the Bluetooth connection for the cloud sensors by disabling cloud mode in the app settings.
        public static let description = RuuviLocalization.tr("Localizable", "TagSettings.PairError.CloudMode.description", fallback: "The sensor cannot be connected to via Bluetooth when the cloud mode is active. You can re-enable the Bluetooth connection for the cloud sensors by disabling cloud mode in the app settings.")
      }
      public enum Timeout {
        /// Connection timed out. Pairing was unsuccessful. Please try again.
        public static let description = RuuviLocalization.tr("Localizable", "TagSettings.PairError.Timeout.description", fallback: "Connection timed out. Pairing was unsuccessful. Please try again.")
      }
    }
    public enum PressureAlert {
      /// Air Pressure (%@)
      public static func title(_ p1: Any) -> String {
        return RuuviLocalization.tr("Localizable", "TagSettings.PressureAlert.title", String(describing: p1), fallback: "Air Pressure (%@)")
      }
    }
    public enum RemoveThisSensor {
      /// Remove this sensor
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.RemoveThisSensor.title", fallback: "Remove this sensor")
    }
    public enum SectionHeader {
      public enum BTConnection {
        /// BLUETOOTH CONNECTION
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.BTConnection.title", fallback: "BLUETOOTH CONNECTION")
      }
      public enum Calibration {
        /// CALIBRATION
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.Calibration.title", fallback: "CALIBRATION")
      }
      public enum Firmware {
        /// Firmware
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.Firmware.title", fallback: "Firmware")
      }
      public enum General {
        /// General
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.General.title", fallback: "General")
      }
      public enum Name {
        /// NAME
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.Name.title", fallback: "NAME")
      }
      public enum NetworkInfo {
        /// NETWORK INFO
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.NetworkInfo.title", fallback: "NETWORK INFO")
      }
      public enum OffsetCorrection {
        /// OFFSET CORRECTION
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.OffsetCorrection.Title", fallback: "OFFSET CORRECTION")
      }
      public enum Remove {
        /// REMOVE
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.SectionHeader.Remove.title", fallback: "REMOVE")
      }
    }
    public enum Share {
      /// Share
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Share.title", fallback: "Share")
    }
    public enum Shared {
      /// Shared
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.Shared.title", fallback: "Shared")
    }
    public enum Uuid {
      public enum Alert {
        /// UUID
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.UUID.Alert.title", fallback: "UUID")
      }
    }
    public enum UpdateFirmware {
      public enum Alert {
        /// In order to see missing values:
        /// If you are using the latest firmware, set RAWv2 mode by pressing "B" on a sensor.
        /// Or update your sensor with the latest firmware.
        public static let message = RuuviLocalization.tr("Localizable", "TagSettings.UpdateFirmware.Alert.message", fallback: "In order to see missing values:\nIf you are using the latest firmware, set RAWv2 mode by pressing \"B\" on a sensor.\nOr update your sensor with the latest firmware.")
        /// RAWv2 mode is required
        public static let title = RuuviLocalization.tr("Localizable", "TagSettings.UpdateFirmware.Alert.title", fallback: "RAWv2 mode is required")
        public enum Buttons {
          public enum LearnMore {
            /// Learn more
            public static let title = RuuviLocalization.tr("Localizable", "TagSettings.UpdateFirmware.Alert.Buttons.LearnMore.title", fallback: "Learn more")
          }
        }
      }
    }
    public enum AccelerationXTitleLabel {
      /// Acceleration X
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.accelerationXTitleLabel.text", fallback: "Acceleration X")
    }
    public enum AccelerationYTitleLabel {
      /// Acceleration Y
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.accelerationYTitleLabel.text", fallback: "Acceleration Y")
    }
    public enum AccelerationZTitleLabel {
      /// Acceleration Z
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.accelerationZTitleLabel.text", fallback: "Acceleration Z")
    }
    public enum BackgroundImageLabel {
      /// Background image
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.backgroundImageLabel.text", fallback: "Background image")
    }
    public enum BatteryVoltageTitleLabel {
      /// Battery Voltage
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.batteryVoltageTitleLabel.text", fallback: "Battery Voltage")
    }
    public enum ConfirmSharedTagRemovalDialog {
      /// If you remove the sensor, the owner of the sensor will be notified and you will not be able to access the sensor anymore.
      public static let message = RuuviLocalization.tr("Localizable", "TagSettings.confirmSharedTagRemovalDialog.message", fallback: "If you remove the sensor, the owner of the sensor will be notified and you will not be able to access the sensor anymore.")
    }
    public enum ConfirmTagRemovalDialog {
      /// Do you want to remove the sensor? You can add it again later, if needed.
      public static let message = RuuviLocalization.tr("Localizable", "TagSettings.confirmTagRemovalDialog.message", fallback: "Do you want to remove the sensor? You can add it again later, if needed.")
      /// Remove sensor
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.confirmTagRemovalDialog.title", fallback: "Remove sensor")
    }
    public enum ConfirmTagUnclaimAndRemoveDialog {
      /// By removing the sensor, your sensor ownership status will be revoked. After removal, someone else can claim ownership of the sensor. Each Ruuvi sensor can have only one owner.
      public static let message = RuuviLocalization.tr("Localizable", "TagSettings.confirmTagUnclaimAndRemoveDialog.message", fallback: "By removing the sensor, your sensor ownership status will be revoked. After removal, someone else can claim ownership of the sensor. Each Ruuvi sensor can have only one owner.")
    }
    public enum DataFormatTitleLabel {
      /// Data Format
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.dataFormatTitleLabel.text", fallback: "Data Format")
    }
    public enum DataSourceTitleLabel {
      /// Data Received Via
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.dataSourceTitleLabel.text", fallback: "Data Received Via")
    }
    public enum DewPointAlertTitleLabel {
      /// Dew Point
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.dewPointAlertTitleLabel.text", fallback: "Dew Point")
    }
    public enum HumidityTitleLabel {
      /// Humidity
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.humidityTitleLabel.text", fallback: "Humidity")
    }
    public enum MacAddressTitleLabel {
      /// MAC Address
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.macAddressTitleLabel.text", fallback: "MAC Address")
    }
    public enum McTitleLabel {
      /// Movement Counter
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.mcTitleLabel.text", fallback: "Movement Counter")
    }
    public enum MsnTitleLabel {
      /// Measurement Sequence Number
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.msnTitleLabel.text", fallback: "Measurement Sequence Number")
    }
    public enum NavigationItem {
      /// Sensor Settings
      public static let title = RuuviLocalization.tr("Localizable", "TagSettings.navigationItem.title", fallback: "Sensor Settings")
    }
    public enum RssiTitleLabel {
      /// Signal Strength (RSSI)
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.rssiTitleLabel.text", fallback: "Signal Strength (RSSI)")
    }
    public enum TagNameTitleLabel {
      /// Name
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.tagNameTitleLabel.text", fallback: "Name")
      public enum Rename {
        /// Your sensors are displayed in alphabetical order.
        public static let text = RuuviLocalization.tr("Localizable", "TagSettings.tagNameTitleLabel.rename.text", fallback: "Your sensors are displayed in alphabetical order.")
      }
    }
    public enum TemperatureAlertTitleLabel {
      /// Temperature (%@)
      public static func text(_ p1: Any) -> String {
        return RuuviLocalization.tr("Localizable", "TagSettings.temperatureAlertTitleLabel.text", String(describing: p1), fallback: "Temperature (%@)")
      }
    }
    public enum TxPowerTitleLabel {
      /// Tx Power
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.txPowerTitleLabel.text", fallback: "Tx Power")
    }
    public enum UuidTitleLabel {
      /// UUID
      public static let text = RuuviLocalization.tr("Localizable", "TagSettings.uuidTitleLabel.text", fallback: "UUID")
    }
  }
  public enum TagsManagerPresenter {
    public enum SignOutConfirmAlert {
      /// When you sign out, sensors the ownerships of which you've claimed on the sensor Settings page will be automatically removed from the app. When you sign in again using the same email address, the sensors will be returned from the cloud.
      /// 
      /// Do you want to sign out?
      public static let message = RuuviLocalization.tr("Localizable", "TagsManagerPresenter.SignOutConfirmAlert.Message", fallback: "When you sign out, sensors the ownerships of which you've claimed on the sensor Settings page will be automatically removed from the app. When you sign in again using the same email address, the sensors will be returned from the cloud.\n\nDo you want to sign out?")
    }
  }
  public enum TemperatureUnit {
    public enum Celsius {
      /// Celsius (℃)
      public static let title = RuuviLocalization.tr("Localizable", "TemperatureUnit.Celsius.title", fallback: "Celsius (℃)")
    }
    public enum Fahrenheit {
      /// Fahrenheit (℉)
      public static let title = RuuviLocalization.tr("Localizable", "TemperatureUnit.Fahrenheit.title", fallback: "Fahrenheit (℉)")
    }
    public enum Kelvin {
      /// Kelvin (K)
      public static let title = RuuviLocalization.tr("Localizable", "TemperatureUnit.Kelvin.title", fallback: "Kelvin (K)")
    }
  }
  public enum UnexpectedError {
    /// Attempt to read data from Realm without LUID
    public static let attemptToReadDataFromRealmWithoutLUID = RuuviLocalization.tr("Localizable", "UnexpectedError.attemptToReadDataFromRealmWithoutLUID", fallback: "Attempt to read data from Realm without LUID")
    /// Both local and MAC identifiers are nil
    public static let bothLuidAndMacAreNil = RuuviLocalization.tr("Localizable", "UnexpectedError.bothLuidAndMacAreNil", fallback: "Both local and MAC identifiers are nil")
    /// Both callback result and error are nil
    public static let callbackErrorAndResultAreNil = RuuviLocalization.tr("Localizable", "UnexpectedError.callbackErrorAndResultAreNil", fallback: "Both callback result and error are nil")
    /// Caller was deallocated during operation
    public static let callerDeinitedDuringOperation = RuuviLocalization.tr("Localizable", "UnexpectedError.callerDeinitedDuringOperation", fallback: "Caller was deallocated during operation")
    /// Failed to find logs for the sensor
    public static let failedToFindLogsForTheTag = RuuviLocalization.tr("Localizable", "UnexpectedError.failedToFindLogsForTheTag", fallback: "Failed to find logs for the sensor")
    /// Failed to find or generate background image
    public static let failedToFindOrGenerateBackgroundImage = RuuviLocalization.tr("Localizable", "UnexpectedError.failedToFindOrGenerateBackgroundImage", fallback: "Failed to find or generate background image")
    /// Failed to find sensor
    public static let failedToFindRuuviTag = RuuviLocalization.tr("Localizable", "UnexpectedError.failedToFindRuuviTag", fallback: "Failed to find sensor")
    /// Failed to find virtual sensor
    public static let failedToFindVirtualTag = RuuviLocalization.tr("Localizable", "UnexpectedError.failedToFindVirtualTag", fallback: "Failed to find virtual sensor")
    /// Failed to reverse geocode location
    public static let failedToReverseGeocodeCoordinate = RuuviLocalization.tr("Localizable", "UnexpectedError.failedToReverseGeocodeCoordinate", fallback: "Failed to reverse geocode location")
    /// View Model UUID is nil
    public static let viewModelUUIDIsNil = RuuviLocalization.tr("Localizable", "UnexpectedError.viewModelUUIDIsNil", fallback: "View Model UUID is nil")
  }
  public enum UnitPressure {
    public enum Hectopascal {
      /// Hectopascal (hPa)
      public static let title = RuuviLocalization.tr("Localizable", "UnitPressure.hectopascal.title", fallback: "Hectopascal (hPa)")
    }
    public enum InchOfMercury {
      /// Inch of mercury (inHg)
      public static let title = RuuviLocalization.tr("Localizable", "UnitPressure.inchOfMercury.title", fallback: "Inch of mercury (inHg)")
    }
    public enum MillimetreOfMercury {
      /// Millimetre of mercury (mmHg)
      public static let title = RuuviLocalization.tr("Localizable", "UnitPressure.millimetreOfMercury.title", fallback: "Millimetre of mercury (mmHg)")
    }
  }
  public enum UpdateFirmware {
    public enum Download {
      /// To start with the update process, first download the latest software package on the device you're going to use for updates. Latest version is available on ruuvi.com/software-update
      public static let content = RuuviLocalization.tr("Localizable", "UpdateFirmware.Download.content", fallback: "To start with the update process, first download the latest software package on the device you're going to use for updates. Latest version is available on ruuvi.com/software-update")
      /// DOWNLOAD LATEST FIRMWARE
      public static let header = RuuviLocalization.tr("Localizable", "UpdateFirmware.Download.header", fallback: "DOWNLOAD LATEST FIRMWARE")
    }
    public enum NextButton {
      /// NEXT
      public static let title = RuuviLocalization.tr("Localizable", "UpdateFirmware.NextButton.title", fallback: "NEXT")
    }
    public enum SetDfu {
      /// Open the RuuviTag's enclosure by pulling it open with your fingers or gently with a flat head screw driver.
      /// 
      /// Set RuuviTag to bootloader mode by holding down button B and pressing reset button R. Red indicator LED light will light up and stay on. If your device has only 1 button, keep it pressed 10 seconds to enter the bootloader.
      public static let content = RuuviLocalization.tr("Localizable", "UpdateFirmware.SetDfu.content", fallback: "Open the RuuviTag's enclosure by pulling it open with your fingers or gently with a flat head screw driver.\n\nSet RuuviTag to bootloader mode by holding down button B and pressing reset button R. Red indicator LED light will light up and stay on. If your device has only 1 button, keep it pressed 10 seconds to enter the bootloader.")
      /// SET RUUVI TAG TO DFU MODE
      public static let header = RuuviLocalization.tr("Localizable", "UpdateFirmware.SetDfu.header", fallback: "SET RUUVI TAG TO DFU MODE")
    }
    public enum Title {
      /// Update Firmware
      public static let text = RuuviLocalization.tr("Localizable", "UpdateFirmware.Title.text", fallback: "Update Firmware")
    }
  }
  public enum UserApiError {
    /// Forbidden
    public static let erForbidden = RuuviLocalization.tr("Localizable", "UserApiError.ER_FORBIDDEN", fallback: "Forbidden")
    /// Internal error
    public static let erInternal = RuuviLocalization.tr("Localizable", "UserApiError.ER_INTERNAL", fallback: "Internal error")
    /// Invalid density mode
    public static let erInvalidDensityMode = RuuviLocalization.tr("Localizable", "UserApiError.ER_INVALID_DENSITY_MODE", fallback: "Invalid density mode")
    /// Invalid email address
    public static let erInvalidEmailAddress = RuuviLocalization.tr("Localizable", "UserApiError.ER_INVALID_EMAIL_ADDRESS", fallback: "Invalid email address")
    /// Invalid request format
    public static let erInvalidFormat = RuuviLocalization.tr("Localizable", "UserApiError.ER_INVALID_FORMAT", fallback: "Invalid request format")
    /// Invalid MAC-address
    public static let erInvalidMacAddress = RuuviLocalization.tr("Localizable", "UserApiError.ER_INVALID_MAC_ADDRESS", fallback: "Invalid MAC-address")
    /// Invalid sort mode
    public static let erInvalidSortMode = RuuviLocalization.tr("Localizable", "UserApiError.ER_INVALID_SORT_MODE", fallback: "Invalid sort mode")
    /// Invalid time range
    public static let erInvalidTimeRange = RuuviLocalization.tr("Localizable", "UserApiError.ER_INVALID_TIME_RANGE", fallback: "Invalid time range")
    /// Missing argument
    public static let erMissingArgument = RuuviLocalization.tr("Localizable", "UserApiError.ER_MISSING_ARGUMENT", fallback: "Missing argument")
    /// In order to share the sensor, you need to have a Ruuvi Gateway router nearby the sensor
    public static let erNoDataToShare = RuuviLocalization.tr("Localizable", "UserApiError.ER_NO_DATA_TO_SHARE", fallback: "In order to share the sensor, you need to have a Ruuvi Gateway router nearby the sensor")
    /// Sensor already claimed by %@
    public static func erSensorAlreadyClaimed(_ p1: Any) -> String {
      return RuuviLocalization.tr("Localizable", "UserApiError.ER_SENSOR_ALREADY_CLAIMED", String(describing: p1), fallback: "Sensor already claimed by %@")
    }
    /// Sensor already claimed
    public static let erSensorAlreadyClaimedNoEmail = RuuviLocalization.tr("Localizable", "UserApiError.ER_SENSOR_ALREADY_CLAIMED_NO_EMAIL", fallback: "Sensor already claimed")
    /// This sensor is already shared
    public static let erSensorAlreadyShared = RuuviLocalization.tr("Localizable", "UserApiError.ER_SENSOR_ALREADY_SHARED", fallback: "This sensor is already shared")
    /// Sensor not found
    public static let erSensorNotFound = RuuviLocalization.tr("Localizable", "UserApiError.ER_SENSOR_NOT_FOUND", fallback: "Sensor not found")
    /// Sensor share limit is reached
    public static let erSensorShareCountReached = RuuviLocalization.tr("Localizable", "UserApiError.ER_SENSOR_SHARE_COUNT_REACHED", fallback: "Sensor share limit is reached")
    /// The share limit is reached
    public static let erShareCountReached = RuuviLocalization.tr("Localizable", "UserApiError.ER_SHARE_COUNT_REACHED", fallback: "The share limit is reached")
    /// Data storage error
    public static let erSubDataStorageError = RuuviLocalization.tr("Localizable", "UserApiError.ER_SUB_DATA_STORAGE_ERROR", fallback: "Data storage error")
    /// No user
    public static let erSubNoUser = RuuviLocalization.tr("Localizable", "UserApiError.ER_SUB_NO_USER", fallback: "No user")
    /// Subscription is not found
    public static let erSubscriptionNotFound = RuuviLocalization.tr("Localizable", "UserApiError.ER_SUBSCRIPTION_NOT_FOUND", fallback: "Subscription is not found")
    /// Too many requests
    public static let erThrottled = RuuviLocalization.tr("Localizable", "UserApiError.ER_THROTTLED", fallback: "Too many requests")
    /// Token is expired
    public static let erTokenExpired = RuuviLocalization.tr("Localizable", "UserApiError.ER_TOKEN_EXPIRED", fallback: "Token is expired")
    /// Unable to send email
    public static let erUnableToSendEmail = RuuviLocalization.tr("Localizable", "UserApiError.ER_UNABLE_TO_SEND_EMAIL", fallback: "Unable to send email")
    /// Unauthorised
    public static let erUnauthorized = RuuviLocalization.tr("Localizable", "UserApiError.ER_UNAUTHORIZED", fallback: "Unauthorised")
    /// User not found
    public static let erUserNotFound = RuuviLocalization.tr("Localizable", "UserApiError.ER_USER_NOT_FOUND", fallback: "User not found")
  }
  public enum WebTagLocationSource {
    /// Your location
    public static let current = RuuviLocalization.tr("Localizable", "WebTagLocationSource.current", fallback: "Your location")
    /// Pick from the map
    public static let manual = RuuviLocalization.tr("Localizable", "WebTagLocationSource.manual", fallback: "Pick from the map")
  }
  public enum WebTagSettings {
    public enum AirHumidityAlert {
      /// Air Humidity
      public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.AirHumidityAlert.title", fallback: "Air Humidity")
    }
    public enum Alerts {
      /// Off
      public static let off = RuuviLocalization.tr("Localizable", "WebTagSettings.Alerts.Off", fallback: "Off")
      public enum DewPoint {
        /// Alert when less than %.0f or more than %.0f
        public static func description(_ p1: Float, _ p2: Float) -> String {
          return RuuviLocalization.tr("Localizable", "WebTagSettings.Alerts.DewPoint.description", p1, p2, fallback: "Alert when less than %.0f or more than %.0f")
        }
      }
      public enum Humidity {
        /// Alert when less than %.0f or more than %.0f
        public static func description(_ p1: Float, _ p2: Float) -> String {
          return RuuviLocalization.tr("Localizable", "WebTagSettings.Alerts.Humidity.description", p1, p2, fallback: "Alert when less than %.0f or more than %.0f")
        }
      }
      public enum Pressure {
        /// Alert when less than %.0f or more than %.0f
        public static func description(_ p1: Float, _ p2: Float) -> String {
          return RuuviLocalization.tr("Localizable", "WebTagSettings.Alerts.Pressure.description", p1, p2, fallback: "Alert when less than %.0f or more than %.0f")
        }
      }
      public enum Temperature {
        /// Alert when less than %.0f or more than %.0f
        public static func description(_ p1: Float, _ p2: Float) -> String {
          return RuuviLocalization.tr("Localizable", "WebTagSettings.Alerts.Temperature.description", p1, p2, fallback: "Alert when less than %.0f or more than %.0f")
        }
      }
    }
    public enum AlertsAreDisabled {
      public enum Dialog {
        public enum BothNoPNPermissionAndNoLocationPermission {
          /// In order to enable virtual sensor alerts please always grant location and notification permissions in Settings.
          public static let message = RuuviLocalization.tr("Localizable", "WebTagSettings.AlertsAreDisabled.Dialog.BothNoPNPermissionAndNoLocationPermission.message", fallback: "In order to enable virtual sensor alerts please always grant location and notification permissions in Settings.")
        }
        public enum Settings {
          /// Settings
          public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.AlertsAreDisabled.Dialog.Settings.title", fallback: "Settings")
        }
      }
    }
    public enum Button {
      public enum Remove {
        /// REMOVE THIS VIRTUAL SENSOR
        public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.Button.Remove.title", fallback: "REMOVE THIS VIRTUAL SENSOR")
      }
    }
    public enum Label {
      public enum BackgroundImage {
        /// BACKGROUND
        /// IMAGE
        public static let text = RuuviLocalization.tr("Localizable", "WebTagSettings.Label.BackgroundImage.text", fallback: "BACKGROUND\nIMAGE")
      }
      public enum Location {
        /// Location
        public static let text = RuuviLocalization.tr("Localizable", "WebTagSettings.Label.Location.text", fallback: "Location")
      }
      public enum TagName {
        /// Sensor Name
        public static let text = RuuviLocalization.tr("Localizable", "WebTagSettings.Label.TagName.text", fallback: "Sensor Name")
      }
      public enum Alerts {
        /// ALERTS
        public static let text = RuuviLocalization.tr("Localizable", "WebTagSettings.Label.alerts.text", fallback: "ALERTS")
      }
      public enum Disabled {
        /// DISABLED?
        public static let text = RuuviLocalization.tr("Localizable", "WebTagSettings.Label.disabled.text", fallback: "DISABLED?")
      }
    }
    public enum Location {
      /// Your location
      public static let current = RuuviLocalization.tr("Localizable", "WebTagSettings.Location.Current", fallback: "Your location")
    }
    public enum PressureAlert {
      /// Air Pressure
      public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.PressureAlert.title", fallback: "Air Pressure")
    }
    public enum SectionHeader {
      public enum MoreInfo {
        /// MORE INFO
        public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.SectionHeader.MoreInfo.title", fallback: "MORE INFO")
      }
      public enum Name {
        /// NAME
        public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.SectionHeader.Name.title", fallback: "NAME")
      }
    }
    public enum ConfirmClearLocationDialog {
      /// Are you sure you want to clear location for this virtual sensor? Current location will be used instead.
      public static let message = RuuviLocalization.tr("Localizable", "WebTagSettings.confirmClearLocationDialog.message", fallback: "Are you sure you want to clear location for this virtual sensor? Current location will be used instead.")
      /// Clear Location
      public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.confirmClearLocationDialog.title", fallback: "Clear Location")
    }
    public enum ConfirmTagRemovalDialog {
      /// Are you sure you want to remove this virtual sensor?
      public static let message = RuuviLocalization.tr("Localizable", "WebTagSettings.confirmTagRemovalDialog.message", fallback: "Are you sure you want to remove this virtual sensor?")
      /// Remove virtual sensor
      public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.confirmTagRemovalDialog.title", fallback: "Remove virtual sensor")
    }
    public enum DewPointAlertTitleLabel {
      /// Dew Point
      public static let text = RuuviLocalization.tr("Localizable", "WebTagSettings.dewPointAlertTitleLabel.text", fallback: "Dew Point")
    }
    public enum NavigationItem {
      /// Virtual Sensor Settings
      public static let title = RuuviLocalization.tr("Localizable", "WebTagSettings.navigationItem.title", fallback: "Virtual Sensor Settings")
    }
    public enum TemperatureAlertTitleLabel {
      /// Temperature
      public static let text = RuuviLocalization.tr("Localizable", "WebTagSettings.temperatureAlertTitleLabel.text", fallback: "Temperature")
    }
  }
  public enum Welcome {
    public enum Description {
      /// To find nearby sensors and receive live sensor data, press 'scan'.
      public static let text = RuuviLocalization.tr("Localizable", "Welcome.description.text", fallback: "To find nearby sensors and receive live sensor data, press 'scan'.")
    }
    public enum Scan {
      /// SCAN
      public static let title = RuuviLocalization.tr("Localizable", "Welcome.scan.title", fallback: "SCAN")
    }
  }
  public enum Widgets {
    public enum Description {
      /// Create widgets of your favourite Ruuvi sensors. Widgets update from the Ruuvi Cloud. A Ruuvi Gateway router is required.
      public static let message = RuuviLocalization.tr("Localizable", "Widgets.Description.message", fallback: "Create widgets of your favourite Ruuvi sensors. Widgets update from the Ruuvi Cloud. A Ruuvi Gateway router is required.")
    }
    public enum Loading {
      /// loading...
      public static let message = RuuviLocalization.tr("Localizable", "Widgets.Loading.message", fallback: "loading...")
    }
    public enum Select {
      public enum Sensor {
        /// Selected Ruuvi sensor
        public static let title = RuuviLocalization.tr("Localizable", "Widgets.Select.Sensor.title", fallback: "Selected Ruuvi sensor")
      }
    }
    public enum Sensor {
      public enum `Type` {
        /// Selected sensor type
        public static let title = RuuviLocalization.tr("Localizable", "Widgets.Sensor.Type.title", fallback: "Selected sensor type")
      }
    }
    public enum Unauthorized {
      public enum Inline {
        /// Sign in to Ruuvi Station
        public static let message = RuuviLocalization.tr("Localizable", "Widgets.Unauthorized.Inline.message", fallback: "Sign in to Ruuvi Station")
      }
      public enum Regular {
        /// Sign in to use the widget.
        public static let message = RuuviLocalization.tr("Localizable", "Widgets.Unauthorized.Regular.message", fallback: "Sign in to use the widget.")
      }
    }
    public enum Unconfigured {
      public enum Circular {
        /// +Add
        public static let message = RuuviLocalization.tr("Localizable", "Widgets.Unconfigured.Circular.message", fallback: "+Add")
      }
      public enum Inline {
        /// Add sensor to use Ruuvi Widget
        public static let message = RuuviLocalization.tr("Localizable", "Widgets.Unconfigured.Inline.message", fallback: "Add sensor to use Ruuvi Widget")
      }
      public enum Rectangular {
        /// Add sensor to use Ruuvi Widget
        public static let message = RuuviLocalization.tr("Localizable", "Widgets.Unconfigured.Rectangular.message", fallback: "Add sensor to use Ruuvi Widget")
      }
      public enum Simple {
        /// Force tap to edit the widget.
        public static let message = RuuviLocalization.tr("Localizable", "Widgets.Unconfigured.Simple.message", fallback: "Force tap to edit the widget.")
      }
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension RuuviLocalization {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
