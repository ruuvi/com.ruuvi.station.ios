import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog17: [LocalizedStringContract] = [
        .init(
            key: "ErrorPresenterAlert.Error", arguments: [],
            defaultValue: { RuuviLocalization.ErrorPresenterAlert.error },
            localized: { RuuviLocalization.ErrorPresenterAlert.error($0) }),
        .init(
            key: "ErrorPresenterAlert.OK", arguments: [],
            defaultValue: { RuuviLocalization.ErrorPresenterAlert.ok },
            localized: { RuuviLocalization.ErrorPresenterAlert.ok($0) }),
        .init(
            key: "ExpectedError.failedToDeleteTag", arguments: [],
            defaultValue: { RuuviLocalization.ExpectedError.failedToDeleteTag },
            localized: { RuuviLocalization.ExpectedError.failedToDeleteTag($0) }),
        .init(
            key: "ExpectedError.isAlreadySyncingLogsWithThisTag", arguments: [],
            defaultValue: { RuuviLocalization.ExpectedError.isAlreadySyncingLogsWithThisTag },
            localized: { RuuviLocalization.ExpectedError.isAlreadySyncingLogsWithThisTag($0) }),
        .init(
            key: "ExpectedError.missingOpenWeatherMapAPIKey", arguments: [],
            defaultValue: { RuuviLocalization.ExpectedError.missingOpenWeatherMapAPIKey },
            localized: { RuuviLocalization.ExpectedError.missingOpenWeatherMapAPIKey($0) }),
        .init(
            key: "ExportService.DataSource", arguments: [],
            defaultValue: { RuuviLocalization.ExportService.dataSource },
            localized: { RuuviLocalization.ExportService.dataSource($0) }),
        .init(
            key: "ExportService.Date", arguments: [],
            defaultValue: { RuuviLocalization.ExportService.date },
            localized: { RuuviLocalization.ExportService.date($0) }),
        .init(
            key: "ForegroundRow.advertisement.title", arguments: [],
            defaultValue: { RuuviLocalization.ForegroundRow.Advertisement.title },
            localized: { RuuviLocalization.ForegroundRow.Advertisement.title($0) }),
        .init(
            key: "Heartbeat.Interval.All.string", arguments: [],
            defaultValue: { RuuviLocalization.Heartbeat.Interval.All.string },
            localized: { RuuviLocalization.Heartbeat.Interval.All.string($0) }),
        .init(
            key: "Heartbeat.Interval.Every.string", arguments: [],
            defaultValue: { RuuviLocalization.Heartbeat.Interval.Every.string },
            localized: { RuuviLocalization.Heartbeat.Interval.Every.string($0) }),
        .init(
            key: "Heartbeat.Interval.Min.string", arguments: [],
            defaultValue: { RuuviLocalization.Heartbeat.Interval.Min.string },
            localized: { RuuviLocalization.Heartbeat.Interval.Min.string($0) }),
        .init(
            key: "HumidityCalibration.Button.Calibrate.title", arguments: [],
            defaultValue: { RuuviLocalization.HumidityCalibration.Button.Calibrate.title },
            localized: { RuuviLocalization.HumidityCalibration.Button.Calibrate.title($0) }),
        .init(
            key: "HumidityCalibration.Button.Clear.title", arguments: [],
            defaultValue: { RuuviLocalization.HumidityCalibration.Button.Clear.title },
            localized: { RuuviLocalization.HumidityCalibration.Button.Clear.title($0) }),
        .init(
            key: "HumidityUnit.Dew.title", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.HumidityUnit.Dew.title("Sensor 1 🌡️") },
            localized: { RuuviLocalization.HumidityUnit.Dew.title("Sensor 1 🌡️", $0) }),
        .init(
            key: "HumidityUnit.Percent.title", arguments: [],
            defaultValue: { RuuviLocalization.HumidityUnit.Percent.title },
            localized: { RuuviLocalization.HumidityUnit.Percent.title($0) }),
        .init(
            key: "HumidityUnit.gm3.title", arguments: [],
            defaultValue: { RuuviLocalization.HumidityUnit.Gm3.title },
            localized: { RuuviLocalization.HumidityUnit.Gm3.title($0) }),
        .init(
            key: "Interval.Day.string", arguments: [],
            defaultValue: { RuuviLocalization.Interval.Day.string },
            localized: { RuuviLocalization.Interval.Day.string($0) }),
        .init(
            key: "Interval.Days.string", arguments: [],
            defaultValue: { RuuviLocalization.Interval.Days.string },
            localized: { RuuviLocalization.Interval.Days.string($0) }),
        .init(
            key: "Language.English", arguments: [],
            defaultValue: { RuuviLocalization.Language.english },
            localized: { RuuviLocalization.Language.english($0) }),
        .init(
            key: "Language.Finnish", arguments: [],
            defaultValue: { RuuviLocalization.Language.finnish },
            localized: { RuuviLocalization.Language.finnish($0) }),
        .init(
            key: "Language.French", arguments: [],
            defaultValue: { RuuviLocalization.Language.french },
            localized: { RuuviLocalization.Language.french($0) }),
        .init(
            key: "Language.German", arguments: [],
            defaultValue: { RuuviLocalization.Language.german },
            localized: { RuuviLocalization.Language.german($0) }),
        .init(
            key: "Language.Polish", arguments: [],
            defaultValue: { RuuviLocalization.Language.polish },
            localized: { RuuviLocalization.Language.polish($0) }),
        .init(
            key: "Language.Swedish", arguments: [],
            defaultValue: { RuuviLocalization.Language.swedish },
            localized: { RuuviLocalization.Language.swedish($0) }),
        .init(
            key: "LocalNotificationsManager.DidConnect.title", arguments: [],
            defaultValue: { RuuviLocalization.LocalNotificationsManager.DidConnect.title },
            localized: { RuuviLocalization.LocalNotificationsManager.DidConnect.title($0) }),
        .init(
            key: "LocalNotificationsManager.DidDisconnect.title", arguments: [],
            defaultValue: { RuuviLocalization.LocalNotificationsManager.DidDisconnect.title },
            localized: { RuuviLocalization.LocalNotificationsManager.DidDisconnect.title($0) }),
        .init(
            key: "LocalNotificationsManager.DidMove.title", arguments: [],
            defaultValue: { RuuviLocalization.LocalNotificationsManager.DidMove.title },
            localized: { RuuviLocalization.LocalNotificationsManager.DidMove.title($0) }),
        .init(
            key: "LocalNotificationsManager.Disable.button", arguments: [],
            defaultValue: { RuuviLocalization.LocalNotificationsManager.Disable.button },
            localized: { RuuviLocalization.LocalNotificationsManager.Disable.button($0) }),
        .init(
            key: "LocalNotificationsManager.Mute.button", arguments: [],
            defaultValue: { RuuviLocalization.LocalNotificationsManager.Mute.button },
            localized: { RuuviLocalization.LocalNotificationsManager.Mute.button($0) }),
        .init(
            key: "Menu.Label.AboutHelp.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Label.AboutHelp.text },
            localized: { RuuviLocalization.Menu.Label.AboutHelp.text($0) }),
        .init(
            key: "Menu.Label.AddAnNewSensor.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Label.AddAnNewSensor.text },
            localized: { RuuviLocalization.Menu.Label.AddAnNewSensor.text($0) }),
        .init(
            key: "Menu.Label.AppSettings.text", arguments: [],
            defaultValue: { RuuviLocalization.Menu.Label.AppSettings.text },
            localized: { RuuviLocalization.Menu.Label.AppSettings.text($0) }),
    ]
}
