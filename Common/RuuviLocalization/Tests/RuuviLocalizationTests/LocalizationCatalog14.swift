import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog14: [LocalizedStringContract] = [
        .init(
            key: "About.More.contents", arguments: [],
            defaultValue: { RuuviLocalization.About.More.contents },
            localized: { RuuviLocalization.About.More.contents($0) }),
        .init(
            key: "About.More.header", arguments: [],
            defaultValue: { RuuviLocalization.About.More.header },
            localized: { RuuviLocalization.About.More.header($0) }),
        .init(
            key: "About.OpenSource.contents", arguments: [],
            defaultValue: { RuuviLocalization.About.OpenSource.contents },
            localized: { RuuviLocalization.About.OpenSource.contents($0) }),
        .init(
            key: "About.OpenSource.header", arguments: [],
            defaultValue: { RuuviLocalization.About.OpenSource.header },
            localized: { RuuviLocalization.About.OpenSource.header($0) }),
        .init(
            key: "About.OperationsManual.contents", arguments: [],
            defaultValue: { RuuviLocalization.About.OperationsManual.contents },
            localized: { RuuviLocalization.About.OperationsManual.contents($0) }),
        .init(
            key: "About.OperationsManual.header", arguments: [],
            defaultValue: { RuuviLocalization.About.OperationsManual.header },
            localized: { RuuviLocalization.About.OperationsManual.header($0) }),
        .init(
            key: "About.Privacy.contents", arguments: [],
            defaultValue: { RuuviLocalization.About.Privacy.contents },
            localized: { RuuviLocalization.About.Privacy.contents($0) }),
        .init(
            key: "About.Privacy.header", arguments: [],
            defaultValue: { RuuviLocalization.About.Privacy.header },
            localized: { RuuviLocalization.About.Privacy.header($0) }),
        .init(
            key: "About.TagsCount.text", arguments: [1234],
            defaultValue: { RuuviLocalization.About.TagsCount.text(1234) },
            localized: { RuuviLocalization.About.TagsCount.text(1234, $0) }),
        .init(
            key: "About.Troubleshooting.contents", arguments: [],
            defaultValue: { RuuviLocalization.About.Troubleshooting.contents },
            localized: { RuuviLocalization.About.Troubleshooting.contents($0) }),
        .init(
            key: "About.Troubleshooting.header", arguments: [],
            defaultValue: { RuuviLocalization.About.Troubleshooting.header },
            localized: { RuuviLocalization.About.Troubleshooting.header($0) }),
        .init(
            key: "About.Version.text", arguments: [],
            defaultValue: { RuuviLocalization.About.Version.text },
            localized: { RuuviLocalization.About.Version.text($0) }),
        .init(
            key: "BluetoothError.disconnected", arguments: [],
            defaultValue: { RuuviLocalization.BluetoothError.disconnected },
            localized: { RuuviLocalization.BluetoothError.disconnected($0) }),
        .init(
            key: "Cards.Alert.AlreadyLoggedIn.message", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.Cards.Alert.AlreadyLoggedIn.message("Sensor 1 🌡️") },
            localized: { RuuviLocalization.Cards.Alert.AlreadyLoggedIn.message("Sensor 1 🌡️", $0) }),
        .init(
            key: "Cards.BluetoothDisabledAlert.message", arguments: [],
            defaultValue: { RuuviLocalization.Cards.BluetoothDisabledAlert.message },
            localized: { RuuviLocalization.Cards.BluetoothDisabledAlert.message($0) }),
        .init(
            key: "Cards.BluetoothDisabledAlert.title", arguments: [],
            defaultValue: { RuuviLocalization.Cards.BluetoothDisabledAlert.title },
            localized: { RuuviLocalization.Cards.BluetoothDisabledAlert.title($0) }),
        .init(
            key: "Cards.KeepConnectionDialog.message", arguments: [],
            defaultValue: { RuuviLocalization.Cards.KeepConnectionDialog.message },
            localized: { RuuviLocalization.Cards.KeepConnectionDialog.message($0) }),
        .init(
            key: "Cards.KeepConnectionDialog.Dismiss.title", arguments: [],
            defaultValue: { RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title },
            localized: { RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title($0) }),
        .init(
            key: "Cards.KeepConnectionDialog.KeepConnection.title", arguments: [],
            defaultValue: { RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title },
            localized: { RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title($0) }),
        .init(
            key: "Cards.LegacyFirmwareUpdateDialog.message", arguments: [],
            defaultValue: { RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message },
            localized: { RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message($0) }),
        .init(
            key: "Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message", arguments: [],
            defaultValue: { RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message },
            localized: { RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message($0) }),
        .init(
            key: "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title", arguments: [],
            defaultValue: { RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title },
            localized: { RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title($0) }),
        .init(
            key: "Cards.UpdatedLabel.NoData.message", arguments: [],
            defaultValue: { RuuviLocalization.Cards.UpdatedLabel.NoData.message },
            localized: { RuuviLocalization.Cards.UpdatedLabel.NoData.message($0) }),
        .init(
            key: "ChartSettings.AllPoints.description", arguments: [],
            defaultValue: { RuuviLocalization.ChartSettings.AllPoints.description },
            localized: { RuuviLocalization.ChartSettings.AllPoints.description($0) }),
        .init(
            key: "ChartSettings.AllPoints.title", arguments: [],
            defaultValue: { RuuviLocalization.ChartSettings.AllPoints.title },
            localized: { RuuviLocalization.ChartSettings.AllPoints.title($0) }),
        .init(
            key: "ChartSettings.DrawDots.description", arguments: [],
            defaultValue: { RuuviLocalization.ChartSettings.DrawDots.description },
            localized: { RuuviLocalization.ChartSettings.DrawDots.description($0) }),
        .init(
            key: "ChartSettings.DrawDots.title", arguments: [],
            defaultValue: { RuuviLocalization.ChartSettings.DrawDots.title },
            localized: { RuuviLocalization.ChartSettings.DrawDots.title($0) }),
        .init(
            key: "CoreError.failedToGetCurrentLocation", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.failedToGetCurrentLocation },
            localized: { RuuviLocalization.CoreError.failedToGetCurrentLocation($0) }),
        .init(
            key: "CoreError.failedToGetDataFromResponse", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.failedToGetDataFromResponse },
            localized: { RuuviLocalization.CoreError.failedToGetDataFromResponse($0) }),
        .init(
            key: "CoreError.failedToGetDocumentsDirectory", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.failedToGetDocumentsDirectory },
            localized: { RuuviLocalization.CoreError.failedToGetDocumentsDirectory($0) }),
        .init(
            key: "CoreError.failedToGetPngRepresentation", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.failedToGetPngRepresentation },
            localized: { RuuviLocalization.CoreError.failedToGetPngRepresentation($0) }),
        .init(
            key: "CoreError.locationPermissionDenied", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.locationPermissionDenied },
            localized: { RuuviLocalization.CoreError.locationPermissionDenied($0) }),
    ]
}
