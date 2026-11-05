import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog18: [LocalizedStringContract] = [
        .init(
            key: "Menu.Label.Feedback.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Label.Feedback.text },
            localized: { RuuviLocalization.Menu.Label.Feedback.text($0) }),
        .init(
            key: "Menu.Label.GetMoreSensors.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Label.GetMoreSensors.text },
            localized: { RuuviLocalization.Menu.Label.GetMoreSensors.text($0) }),
        .init(
            key: "Menu.Label.MyRuuviAccount.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Label.MyRuuviAccount.text },
            localized: { RuuviLocalization.Menu.Label.MyRuuviAccount.text($0) }),
        .init(
            key: "Menu.Label.WhatToMeasure.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Label.WhatToMeasure.text },
            localized: { RuuviLocalization.Menu.Label.WhatToMeasure.text($0) }),
        .init(
            key: "Menu.LoggedIn.title", arguments: [],
            defaultValue: { RuuviLocalization.Menu.LoggedIn.title },
            localized: { RuuviLocalization.Menu.LoggedIn.title($0) }),
        .init(
            key: "Menu.Measure.URL.IOS", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Measure.Url.ios },
            localized: { RuuviLocalization.Menu.Measure.Url.ios($0) }),
        .init(
            key: "Menu.SignOut.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.SignOut.text },
            localized: { RuuviLocalization.Menu.SignOut.text($0) }),
        .init(
            key: "MyRuuvi.Settings.DeleteAccount.title", arguments: [],
            defaultValue: { RuuviLocalization.MyRuuvi.Settings.DeleteAccount.title },
            localized: { RuuviLocalization.MyRuuvi.Settings.DeleteAccount.title($0) }),
        .init(
            key: "MyRuuvi.Settings.DeleteAccount.Confirmation.message", arguments: [],
            defaultValue: { RuuviLocalization.MyRuuvi.Settings.DeleteAccount.Confirmation.message },
            localized: { RuuviLocalization.MyRuuvi.Settings.DeleteAccount.Confirmation.message($0) }),
        .init(
            key: "OffsetCorrection.CalibrationDescription.text", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.CalibrationDescription.text },
            localized: { RuuviLocalization.OffsetCorrection.CalibrationDescription.text($0) }),
        .init(
            key: "OffsetCorrection.CorrectedValue.title", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.CorrectedValue.title },
            localized: { RuuviLocalization.OffsetCorrection.CorrectedValue.title($0) }),
        .init(
            key: "OffsetCorrection.Dialog.Calibration.ClearConfirm", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.clearConfirm },
            localized: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.clearConfirm($0) }),
        .init(
            key: "OffsetCorrection.Dialog.Calibration.EnterHumidity", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterHumidity("Sensor 1 🌡️") },
            localized: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterHumidity("Sensor 1 🌡️", $0) }),
        .init(
            key: "OffsetCorrection.Dialog.Calibration.EnterPressure", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterPressure("Sensor 1 🌡️") },
            localized: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterPressure("Sensor 1 🌡️", $0) }),
        .init(
            key: "OffsetCorrection.Dialog.Calibration.EnterTemperature", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterTemperature("Sensor 1 🌡️") },
            localized: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterTemperature("Sensor 1 🌡️", $0) }),
        .init(
            key: "OffsetCorrection.Dialog.Calibration.Title", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.title },
            localized: { RuuviLocalization.OffsetCorrection.Dialog.Calibration.title($0) }),
        .init(
            key: "OffsetCorrection.Humidity.Title", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.Humidity.title },
            localized: { RuuviLocalization.OffsetCorrection.Humidity.title($0) }),
        .init(
            key: "OffsetCorrection.OriginalValue.title", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.OriginalValue.title },
            localized: { RuuviLocalization.OffsetCorrection.OriginalValue.title($0) }),
        .init(
            key: "OffsetCorrection.Pressure.Title", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.Pressure.title },
            localized: { RuuviLocalization.OffsetCorrection.Pressure.title($0) }),
        .init(
            key: "OffsetCorrection.Temperature.Title", arguments: [],
            defaultValue: { RuuviLocalization.OffsetCorrection.Temperature.title },
            localized: { RuuviLocalization.OffsetCorrection.Temperature.title($0) }),
        .init(
            key: "Owner.title", arguments: [],
            defaultValue: { RuuviLocalization.Owner.title },
            localized: { RuuviLocalization.Owner.title($0) }),
        .init(
            key: "Owner.Claim.description", arguments: [],
            defaultValue: { RuuviLocalization.Owner.Claim.description },
            localized: { RuuviLocalization.Owner.Claim.description($0) }),
        .init(
            key: "Owner.ClaimOwnership.button", arguments: [],
            defaultValue: { RuuviLocalization.Owner.ClaimOwnership.button },
            localized: { RuuviLocalization.Owner.ClaimOwnership.button($0) }),
        .init(
            key: "PermissionPresenter.settings", arguments: [],
            defaultValue: { RuuviLocalization.PermissionPresenter.settings },
            localized: { RuuviLocalization.PermissionPresenter.settings($0) }),
        .init(
            key: "PermissionPresenter.NoCameraAccess.message", arguments: [],
            defaultValue: { RuuviLocalization.PermissionPresenter.NoCameraAccess.message },
            localized: { RuuviLocalization.PermissionPresenter.NoCameraAccess.message($0) }),
        .init(
            key: "PermissionPresenter.NoLocationAccess.message", arguments: [],
            defaultValue: { RuuviLocalization.PermissionPresenter.NoLocationAccess.message },
            localized: { RuuviLocalization.PermissionPresenter.NoLocationAccess.message($0) }),
        .init(
            key: "PermissionPresenter.NoPhotoLibraryAccess.message", arguments: [],
            defaultValue: { RuuviLocalization.PermissionPresenter.NoPhotoLibraryAccess.message },
            localized: { RuuviLocalization.PermissionPresenter.NoPhotoLibraryAccess.message($0) }),
        .init(
            key: "PermissionPresenter.NoPushNotificationsPermission.message", arguments: [],
            defaultValue: { RuuviLocalization.PermissionPresenter.NoPushNotificationsPermission.message },
            localized: { RuuviLocalization.PermissionPresenter.NoPushNotificationsPermission.message($0) }),
        .init(
            key: "Ruuvi.BuySensors.Menu.URL.IOS", arguments: [],
            defaultValue: { RuuviLocalization.Ruuvi.BuySensors.Menu.Url.ios },
            localized: { RuuviLocalization.Ruuvi.BuySensors.Menu.Url.ios($0) }),
        .init(
            key: "Ruuvi.BuySensors.URL.IOS", arguments: [],
            defaultValue: { RuuviLocalization.Ruuvi.BuySensors.Url.ios },
            localized: { RuuviLocalization.Ruuvi.BuySensors.Url.ios($0) }),
        .init(
            key: "RuuviCloudApiError.emptyResponse", arguments: [],
            defaultValue: { RuuviLocalization.RuuviCloudApiError.emptyResponse },
            localized: { RuuviLocalization.RuuviCloudApiError.emptyResponse($0) }),
        .init(
            key: "RuuviCloudApiError.failedToGetDataFromResponse", arguments: [],
            defaultValue: { RuuviLocalization.RuuviCloudApiError.failedToGetDataFromResponse },
            localized: { RuuviLocalization.RuuviCloudApiError.failedToGetDataFromResponse($0) }),
    ]
}
