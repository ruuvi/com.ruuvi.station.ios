import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog20: [LocalizedStringContract] = [
        .init(
            key: "Settings.Language.Dialog.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Language.Dialog.title },
            localized: { RuuviLocalization.Settings.Language.Dialog.title($0) }),
        .init(
            key: "Settings.Measurement.Resolution.description", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Measurement.Resolution.description },
            localized: { RuuviLocalization.Settings.Measurement.Resolution.description($0) }),
        .init(
            key: "Settings.Measurement.Resolution.empty", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Measurement.Resolution.empty },
            localized: { RuuviLocalization.Settings.Measurement.Resolution.empty($0) }),
        .init(
            key: "Settings.Measurement.Resolution.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Measurement.Resolution.title },
            localized: { RuuviLocalization.Settings.Measurement.Resolution.title($0) }),
        .init(
            key: "Settings.Measurement.Unit.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Measurement.Unit.title },
            localized: { RuuviLocalization.Settings.Measurement.Unit.title($0) }),
        .init(
            key: "Settings.Pressure.Resolution.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Pressure.Resolution.title },
            localized: { RuuviLocalization.Settings.Pressure.Resolution.title($0) }),
        .init(
            key: "Settings.Temperature.Resolution.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Temperature.Resolution.title },
            localized: { RuuviLocalization.Settings.Temperature.Resolution.title($0) }),
        .init(
            key: "Settings.navigationItem.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.NavigationItem.title },
            localized: { RuuviLocalization.Settings.NavigationItem.title($0) }),
        .init(
            key: "Share.Success.message", arguments: [],
            defaultValue: { RuuviLocalization.Share.Success.message },
            localized: { RuuviLocalization.Share.Success.message($0) }),
        .init(
            key: "SharePresenter.UnshareSensor.Message", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.SharePresenter.UnshareSensor.message("Sensor 1 🌡️") },
            localized: { RuuviLocalization.SharePresenter.UnshareSensor.message("Sensor 1 🌡️", $0) }),
        .init(
            key: "ShareViewController.Description", arguments: [],
            defaultValue: { RuuviLocalization.ShareViewController.description },
            localized: { RuuviLocalization.ShareViewController.description($0) }),
        .init(
            key: "ShareViewController.Title", arguments: [],
            defaultValue: { RuuviLocalization.ShareViewController.title },
            localized: { RuuviLocalization.ShareViewController.title($0) }),
        .init(
            key: "ShareViewController.addFriend.Title", arguments: [],
            defaultValue: { RuuviLocalization.ShareViewController.AddFriend.title },
            localized: { RuuviLocalization.ShareViewController.AddFriend.title($0) }),
        .init(
            key: "ShareViewController.emailTextField.placeholder", arguments: [],
            defaultValue: { RuuviLocalization.ShareViewController.EmailTextField.placeholder },
            localized: { RuuviLocalization.ShareViewController.EmailTextField.placeholder($0) }),
        .init(
            key: "SignIn.CheckMailbox", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.SignIn.checkMailbox("Sensor 1 🌡️") },
            localized: { RuuviLocalization.SignIn.checkMailbox("Sensor 1 🌡️", $0) }),
        .init(
            key: "SignIn.EmailMismatch.Alert.message", arguments: ["Sensor 1 🌡️", "Sensor 2 🌡️", "Sensor 3 🌡️"],
            defaultValue: {
                RuuviLocalization.SignIn.EmailMismatch.Alert.message("Sensor 1 🌡️", "Sensor 2 🌡️", "Sensor 3 🌡️")
            },
            localized: {
                RuuviLocalization.SignIn.EmailMismatch.Alert.message("Sensor 1 🌡️", "Sensor 2 🌡️", "Sensor 3 🌡️", $0)
            }),
        .init(
            key: "SignIn.EmailMissing.Alert.message", arguments: [],
            defaultValue: { RuuviLocalization.SignIn.EmailMissing.Alert.message },
            localized: { RuuviLocalization.SignIn.EmailMissing.Alert.message($0) }),
        .init(
            key: "SignIn.Sync.message", arguments: [],
            defaultValue: { RuuviLocalization.SignIn.Sync.message },
            localized: { RuuviLocalization.SignIn.Sync.message($0) }),
        .init(
            key: "SignIn.Title.text", arguments: [],
            defaultValue: { RuuviLocalization.SignIn.Title.text },
            localized: { RuuviLocalization.SignIn.Title.text($0) }),
        .init(
            key: "TagCharts.AbortSync.Alert.message", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.AbortSync.Alert.message },
            localized: { RuuviLocalization.TagCharts.AbortSync.Alert.message($0) }),
        .init(
            key: "TagCharts.AbortSync.Button.title", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.AbortSync.Button.title },
            localized: { RuuviLocalization.TagCharts.AbortSync.Button.title($0) }),
        .init(
            key: "TagCharts.BluetoothDisabledAlert.message", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.BluetoothDisabledAlert.message },
            localized: { RuuviLocalization.TagCharts.BluetoothDisabledAlert.message($0) }),
        .init(
            key: "TagCharts.BluetoothDisabledAlert.title", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.BluetoothDisabledAlert.title },
            localized: { RuuviLocalization.TagCharts.BluetoothDisabledAlert.title($0) }),
        .init(
            key: "TagCharts.Clear.title", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Clear.title },
            localized: { RuuviLocalization.TagCharts.Clear.title($0) }),
        .init(
            key: "TagCharts.DeleteHistoryConfirmationDialog.title", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.DeleteHistoryConfirmationDialog.title },
            localized: { RuuviLocalization.TagCharts.DeleteHistoryConfirmationDialog.title($0) }),
        .init(
            key: "TagCharts.Dismiss.Alert.message", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Dismiss.Alert.message },
            localized: { RuuviLocalization.TagCharts.Dismiss.Alert.message($0) }),
        .init(
            key: "TagCharts.FailedToSyncDialog.message", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.FailedToSyncDialog.message },
            localized: { RuuviLocalization.TagCharts.FailedToSyncDialog.message($0) }),
        .init(
            key: "TagCharts.FailedToSyncDialog.title", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.FailedToSyncDialog.title },
            localized: { RuuviLocalization.TagCharts.FailedToSyncDialog.title($0) }),
        .init(
            key: "TagCharts.Status.Connecting", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Status.connecting },
            localized: { RuuviLocalization.TagCharts.Status.connecting($0) }),
        .init(
            key: "TagCharts.Status.Disconnecting", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Status.disconnecting },
            localized: { RuuviLocalization.TagCharts.Status.disconnecting($0) }),
        .init(
            key: "TagCharts.Status.Error", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Status.error },
            localized: { RuuviLocalization.TagCharts.Status.error($0) }),
        .init(
            key: "TagCharts.Status.Queued", arguments: [],
            defaultValue: { RuuviLocalization.TagCharts.Status.queued },
            localized: { RuuviLocalization.TagCharts.Status.queued($0) }),
    ]
}
