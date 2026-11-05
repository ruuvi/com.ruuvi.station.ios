import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog21: [LocalizedStringContract] = [
        .init(
            key: "TagCharts.Status.Serving", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Status.serving },
            localized: { RuuviLocalization.TagCharts.Status.serving($0) }),
        .init(
            key: "TagCharts.Status.Success", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Status.success },
            localized: { RuuviLocalization.TagCharts.Status.success($0) }),
        .init(
            key: "TagCharts.Sync.title", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Sync.title },
            localized: { RuuviLocalization.TagCharts.Sync.title($0) }),
        .init(
            key: "TagCharts.TryAgain.title", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.TryAgain.title },
            localized: { RuuviLocalization.TagCharts.TryAgain.title($0) }),
        .init(
            key: "TagSettings.Alert.CustomDescription.placeholder", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Alert.CustomDescription.placeholder },
            localized: { RuuviLocalization.TagSettings.Alert.CustomDescription.placeholder($0) }),
        .init(
            key: "TagSettings.Alert.CustomDescription.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Alert.CustomDescription.title },
            localized: { RuuviLocalization.TagSettings.Alert.CustomDescription.title($0) }),
        .init(
            key: "TagSettings.AlertSettings.Dialog.Max", arguments: [Float(13.25)],
            defaultValue: { RuuviLocalization.TagSettings.AlertSettings.Dialog.max(Float(13.25)) },
            localized: { RuuviLocalization.TagSettings.AlertSettings.Dialog.max(Float(13.25), $0) }),
        .init(
            key: "TagSettings.AlertSettings.Dialog.Min", arguments: [Float(13.25)],
            defaultValue: { RuuviLocalization.TagSettings.AlertSettings.Dialog.min(Float(13.25)) },
            localized: { RuuviLocalization.TagSettings.AlertSettings.Dialog.min(Float(13.25), $0) }),
        .init(
            key: "TagSettings.Alerts.description", arguments: ["Sensor 1 🌡️", "Sensor 2 🌡️"],
            defaultValue: { RuuviLocalization.TagSettings.Alerts.description("Sensor 1 🌡️", "Sensor 2 🌡️") },
            localized: { RuuviLocalization.TagSettings.Alerts.description("Sensor 1 🌡️", "Sensor 2 🌡️", $0) }),
        .init(
            key: "TagSettings.Alerts.Connection.description", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Alerts.Connection.description },
            localized: { RuuviLocalization.TagSettings.Alerts.Connection.description($0) }),
        .init(
            key: "TagSettings.Alerts.DeliveryPrompt.GoToBackgroundScanning.button", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.GoToBackgroundScanning.button },
            localized: { RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.GoToBackgroundScanning.button($0) }),
        .init(
            key: "TagSettings.Alerts.DeliveryPrompt.GoToSensorSettings.button", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.GoToSensorSettings.button },
            localized: { RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.GoToSensorSettings.button($0) }),
        .init(
            key: "TagSettings.Alerts.DeliveryPrompt.RuuviAirBackgroundScanningDisabled.text", arguments: [],
            defaultValue: {
                RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.RuuviAirBackgroundScanningDisabled.text
            },
            localized: {
                RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.RuuviAirBackgroundScanningDisabled.text($0)
            }),
        .init(
            key: "TagSettings.Alerts.DeliveryPrompt.RuuviTagBackgroundScanningDisabled.text", arguments: [],
            defaultValue: {
                RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.RuuviTagBackgroundScanningDisabled.text
            },
            localized: {
                RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.RuuviTagBackgroundScanningDisabled.text($0)
            }),
        .init(
            key: "TagSettings.Alerts.DeliveryPrompt.RuuviTagUnpaired.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.RuuviTagUnpaired.text },
            localized: { RuuviLocalization.TagSettings.Alerts.DeliveryPrompt.RuuviTagUnpaired.text($0) }),
        .init(
            key: "TagSettings.Alerts.Movement.description", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Alerts.Movement.description },
            localized: { RuuviLocalization.TagSettings.Alerts.Movement.description($0) }),
        .init(
            key: "TagSettings.BatteryStatusLabel.Ok.message", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.BatteryStatusLabel.Ok.message },
            localized: { RuuviLocalization.TagSettings.BatteryStatusLabel.Ok.message($0) }),
        .init(
            key: "TagSettings.BatteryStatusLabel.Replace.message", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.BatteryStatusLabel.Replace.message },
            localized: { RuuviLocalization.TagSettings.BatteryStatusLabel.Replace.message($0) }),
        .init(
            key: "TagSettings.DataSource.Advertisement.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.DataSource.Advertisement.title },
            localized: { RuuviLocalization.TagSettings.DataSource.Advertisement.title($0) }),
        .init(
            key: "TagSettings.DataSource.Heartbeat.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.DataSource.Heartbeat.title },
            localized: { RuuviLocalization.TagSettings.DataSource.Heartbeat.title($0) }),
        .init(
            key: "TagSettings.DataSource.Network.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.DataSource.Network.title },
            localized: { RuuviLocalization.TagSettings.DataSource.Network.title($0) }),
        .init(
            key: "TagSettings.Firmware.CurrentVersion", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Firmware.currentVersion },
            localized: { RuuviLocalization.TagSettings.Firmware.currentVersion($0) }),
        .init(
            key: "TagSettings.Firmware.UpdateFirmware", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Firmware.updateFirmware },
            localized: { RuuviLocalization.TagSettings.Firmware.updateFirmware($0) }),
        .init(
            key: "TagSettings.General.Owner.none", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.General.Owner.`none` },
            localized: { RuuviLocalization.TagSettings.General.Owner.`none`($0) }),
        .init(
            key: "TagSettings.Label.alerts.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Label.Alerts.text },
            localized: { RuuviLocalization.TagSettings.Label.Alerts.text($0) }),
        .init(
            key: "TagSettings.Label.alertsTopMenuHint.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Label.AlertsTopMenuHint.text },
            localized: { RuuviLocalization.TagSettings.Label.AlertsTopMenuHint.text($0) }),
        .init(
            key: "TagSettings.Label.noValues.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Label.NoValues.text },
            localized: { RuuviLocalization.TagSettings.Label.NoValues.text($0) }),
        .init(
            key: "TagSettings.Mac.Alert.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Mac.Alert.title },
            localized: { RuuviLocalization.TagSettings.Mac.Alert.title($0) }),
        .init(
            key: "TagSettings.NetworkInfo.Owner", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.NetworkInfo.owner },
            localized: { RuuviLocalization.TagSettings.NetworkInfo.owner($0) }),
        .init(
            key: "TagSettings.NotShared.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.NotShared.title },
            localized: { RuuviLocalization.TagSettings.NotShared.title($0) }),
        .init(
            key: "TagSettings.OffsetCorrection.Humidity", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.OffsetCorrection.humidity },
            localized: { RuuviLocalization.TagSettings.OffsetCorrection.humidity($0) }),
        .init(
            key: "TagSettings.OffsetCorrection.Temperature", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.OffsetCorrection.temperature },
            localized: { RuuviLocalization.TagSettings.OffsetCorrection.temperature($0) }),
    ]
}
