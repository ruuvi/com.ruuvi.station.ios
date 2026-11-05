import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog19: [LocalizedStringContract] = [
        .init(
            key: "RuuviCloudApiError.unexpectedHTTPStatusCode", arguments: [],
            defaultValue: { RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCode },
            localized: { RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCode($0) }),
        .init(
            key: "RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry", arguments: [],
            defaultValue: { RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry },
            localized: { RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry($0) }),
        .init(
            key: "RuuviCloudError.NotAuthorized", arguments: [],
            defaultValue: { RuuviLocalization.RuuviCloudError.notAuthorized },
            localized: { RuuviLocalization.RuuviCloudError.notAuthorized($0) }),
        .init(
            key: "RuuviLocalError.failedToGetDocumentsDirectory", arguments: [],
            defaultValue: { RuuviLocalization.RuuviLocalError.failedToGetDocumentsDirectory },
            localized: { RuuviLocalization.RuuviLocalError.failedToGetDocumentsDirectory($0) }),
        .init(
            key: "RuuviLocalError.failedToGetJpegRepresentation", arguments: [],
            defaultValue: { RuuviLocalization.RuuviLocalError.failedToGetJpegRepresentation },
            localized: { RuuviLocalization.RuuviLocalError.failedToGetJpegRepresentation($0) }),
        .init(
            key: "RuuviPersistenceError.failedToFindRuuviTag", arguments: [],
            defaultValue: { RuuviLocalization.RuuviPersistenceError.failedToFindRuuviTag },
            localized: { RuuviLocalization.RuuviPersistenceError.failedToFindRuuviTag($0) }),
        .init(
            key: "RuuviServiceError.bothLuidAndMacAreNil", arguments: [],
            defaultValue: { RuuviLocalization.RuuviServiceError.bothLuidAndMacAreNil },
            localized: { RuuviLocalization.RuuviServiceError.bothLuidAndMacAreNil($0) }),
        .init(
            key: "RuuviServiceError.failedToFindOrGenerateBackgroundImage", arguments: [],
            defaultValue: { RuuviLocalization.RuuviServiceError.failedToFindOrGenerateBackgroundImage },
            localized: { RuuviLocalization.RuuviServiceError.failedToFindOrGenerateBackgroundImage($0) }),
        .init(
            key: "RuuviServiceError.failedToGetJpegRepresentation", arguments: [],
            defaultValue: { RuuviLocalization.RuuviServiceError.failedToGetJpegRepresentation },
            localized: { RuuviLocalization.RuuviServiceError.failedToGetJpegRepresentation($0) }),
        .init(
            key: "RuuviServiceError.failedToParseNetworkResponse", arguments: [],
            defaultValue: { RuuviLocalization.RuuviServiceError.failedToParseNetworkResponse },
            localized: { RuuviLocalization.RuuviServiceError.failedToParseNetworkResponse($0) }),
        .init(
            key: "RuuviServiceError.macIdIsNil", arguments: [],
            defaultValue: { RuuviLocalization.RuuviServiceError.macIdIsNil },
            localized: { RuuviLocalization.RuuviServiceError.macIdIsNil($0) }),
        .init(
            key: "RuuviServiceError.pictureUrlIsNil", arguments: [],
            defaultValue: { RuuviLocalization.RuuviServiceError.pictureUrlIsNil },
            localized: { RuuviLocalization.RuuviServiceError.pictureUrlIsNil($0) }),
        .init(
            key: "Settings.BackgroundScanning.interval", arguments: [],
            defaultValue: { RuuviLocalization.Settings.BackgroundScanning.interval },
            localized: { RuuviLocalization.Settings.BackgroundScanning.interval($0) }),
        .init(
            key: "Settings.BackgroundScanning.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.BackgroundScanning.title },
            localized: { RuuviLocalization.Settings.BackgroundScanning.title($0) }),
        .init(
            key: "Settings.BackgroundScanning.Bluetooth.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.BackgroundScanning.Bluetooth.title },
            localized: { RuuviLocalization.Settings.BackgroundScanning.Bluetooth.title($0) }),
        .init(
            key: "Settings.BackgroundScanning.DisableConfirmation.message", arguments: [],
            defaultValue: { RuuviLocalization.Settings.BackgroundScanning.DisableConfirmation.message },
            localized: { RuuviLocalization.Settings.BackgroundScanning.DisableConfirmation.message($0) }),
        .init(
            key: "Settings.BackgroundScanning.Footer.message", arguments: [],
            defaultValue: { RuuviLocalization.Settings.BackgroundScanning.Footer.message },
            localized: { RuuviLocalization.Settings.BackgroundScanning.Footer.message($0) }),
        .init(
            key: "Settings.ChooseHumidityUnit.text", arguments: [],
            defaultValue: { RuuviLocalization.Settings.ChooseHumidityUnit.text },
            localized: { RuuviLocalization.Settings.ChooseHumidityUnit.text($0) }),
        .init(
            key: "Settings.ChoosePressureUnit.text", arguments: [],
            defaultValue: { RuuviLocalization.Settings.ChoosePressureUnit.text },
            localized: { RuuviLocalization.Settings.ChoosePressureUnit.text($0) }),
        .init(
            key: "Settings.ChooseTemperatureUnit.text", arguments: [],
            defaultValue: { RuuviLocalization.Settings.ChooseTemperatureUnit.text },
            localized: { RuuviLocalization.Settings.ChooseTemperatureUnit.text($0) }),
        .init(
            key: "Settings.GlobalUnits.description", arguments: [],
            defaultValue: { RuuviLocalization.Settings.GlobalUnits.description },
            localized: { RuuviLocalization.Settings.GlobalUnits.description($0) }),
        .init(
            key: "Settings.Humidity.Resolution.title", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Humidity.Resolution.title },
            localized: { RuuviLocalization.Settings.Humidity.Resolution.title($0) }),
        .init(
            key: "Settings.Label.Chart", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.chart },
            localized: { RuuviLocalization.Settings.Label.chart($0) }),
        .init(
            key: "Settings.Label.CloudMode", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.cloudMode },
            localized: { RuuviLocalization.Settings.Label.cloudMode($0) }),
        .init(
            key: "Settings.Label.Defaults", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.defaults },
            localized: { RuuviLocalization.Settings.Label.defaults($0) }),
        .init(
            key: "Settings.Label.GlobalUnits", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.globalUnits },
            localized: { RuuviLocalization.Settings.Label.globalUnits($0) }),
        .init(
            key: "Settings.Label.CloudMode.description", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.CloudMode.description },
            localized: { RuuviLocalization.Settings.Label.CloudMode.description($0) }),
        .init(
            key: "Settings.Label.HumidityUnit.text", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.HumidityUnit.text },
            localized: { RuuviLocalization.Settings.Label.HumidityUnit.text($0) }),
        .init(
            key: "Settings.Label.Language.text", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.Language.text },
            localized: { RuuviLocalization.Settings.Label.Language.text($0) }),
        .init(
            key: "Settings.Label.PressureUnit.text", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.PressureUnit.text },
            localized: { RuuviLocalization.Settings.Label.PressureUnit.text($0) }),
        .init(
            key: "Settings.Label.TemperatureUnit.text", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Label.TemperatureUnit.text },
            localized: { RuuviLocalization.Settings.Label.TemperatureUnit.text($0) }),
        .init(
            key: "Settings.Language.Dialog.message", arguments: [],
            defaultValue: { RuuviLocalization.Settings.Language.Dialog.message },
            localized: { RuuviLocalization.Settings.Language.Dialog.message($0) }),
    ]
}
