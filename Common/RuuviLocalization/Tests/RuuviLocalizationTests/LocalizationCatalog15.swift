import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog15: [LocalizedStringContract] = [
        .init(
            key: "CoreError.locationPermissionNotDetermined", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.locationPermissionNotDetermined },
            localized: { RuuviLocalization.CoreError.locationPermissionNotDetermined($0) }),
        .init(
            key: "CoreError.objectInvalidated", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.objectInvalidated },
            localized: { RuuviLocalization.CoreError.objectInvalidated($0) }),
        .init(
            key: "CoreError.objectNotFound", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.objectNotFound },
            localized: { RuuviLocalization.CoreError.objectNotFound($0) }),
        .init(
            key: "CoreError.unableToSendEmail", arguments: [],
            defaultValue: { RuuviLocalization.CoreError.unableToSendEmail },
            localized: { RuuviLocalization.CoreError.unableToSendEmail($0) }),
        .init(
            key: "DFUUIView.alreadyOnLatest", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.alreadyOnLatest },
            localized: { RuuviLocalization.DFUUIView.alreadyOnLatest($0) }),
        .init(
            key: "DFUUIView.currentTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.currentTitle },
            localized: { RuuviLocalization.DFUUIView.currentTitle($0) }),
        .init(
            key: "DFUUIView.doNotCloseTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.doNotCloseTitle },
            localized: { RuuviLocalization.DFUUIView.doNotCloseTitle($0) }),
        .init(
            key: "DFUUIView.downloadingTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.downloadingTitle },
            localized: { RuuviLocalization.DFUUIView.downloadingTitle($0) }),
        .init(
            key: "DFUUIView.latestTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.latestTitle },
            localized: { RuuviLocalization.DFUUIView.latestTitle($0) }),
        .init(
            key: "DFUUIView.navigationTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.navigationTitle },
            localized: { RuuviLocalization.DFUUIView.navigationTitle($0) }),
        .init(
            key: "DFUUIView.notReportingDescription", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.notReportingDescription },
            localized: { RuuviLocalization.DFUUIView.notReportingDescription($0) }),
        .init(
            key: "DFUUIView.searchingTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.searchingTitle },
            localized: { RuuviLocalization.DFUUIView.searchingTitle($0) }),
        .init(
            key: "DFUUIView.startTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.startTitle },
            localized: { RuuviLocalization.DFUUIView.startTitle($0) }),
        .init(
            key: "DFUUIView.startUpdateProcess", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.startUpdateProcess },
            localized: { RuuviLocalization.DFUUIView.startUpdateProcess($0) }),
        .init(
            key: "DFUUIView.updatingTitle", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.updatingTitle },
            localized: { RuuviLocalization.DFUUIView.updatingTitle($0) }),
        .init(
            key: "DFUUIView.DBMigration.Error.message", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.DBMigration.Error.message },
            localized: { RuuviLocalization.DFUUIView.DBMigration.Error.message($0) }),
        .init(
            key: "DFUUIView.lowBattery.warning.message", arguments: [],
            defaultValue: { RuuviLocalization.DFUUIView.LowBattery.Warning.message },
            localized: { RuuviLocalization.DFUUIView.LowBattery.Warning.message($0) }),
        .init(
            key: "Defaults.AlertsMuteInterval.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.AlertsMuteInterval.title },
            localized: { RuuviLocalization.Defaults.AlertsMuteInterval.title($0) }),
        .init(
            key: "Defaults.AppLaunchRequiredForReview.Count.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.AppLaunchRequiredForReview.Count.title },
            localized: { RuuviLocalization.Defaults.AppLaunchRequiredForReview.Count.title($0) }),
        .init(
            key: "Defaults.AskReviewIfLaunchDivisibleBy.Count.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.AskReviewIfLaunchDivisibleBy.Count.title },
            localized: { RuuviLocalization.Defaults.AskReviewIfLaunchDivisibleBy.Count.title($0) }),
        .init(
            key: "Defaults.BackgroundScanning.foreground.interval", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.BackgroundScanning.Foreground.interval },
            localized: { RuuviLocalization.Defaults.BackgroundScanning.Foreground.interval($0) }),
        .init(
            key: "Defaults.CardsSwipeHint.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.CardsSwipeHint.title },
            localized: { RuuviLocalization.Defaults.CardsSwipeHint.title($0) }),
        .init(
            key: "Defaults.ChartDurationHours.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ChartDurationHours.title },
            localized: { RuuviLocalization.Defaults.ChartDurationHours.title($0) }),
        .init(
            key: "Defaults.ChartIntervalSeconds.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ChartIntervalSeconds.title },
            localized: { RuuviLocalization.Defaults.ChartIntervalSeconds.title($0) }),
        .init(
            key: "Defaults.ChartsSwipeInstructionWasShown.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ChartsSwipeInstructionWasShown.title },
            localized: { RuuviLocalization.Defaults.ChartsSwipeInstructionWasShown.title($0) }),
        .init(
            key: "Defaults.ConnectionTimeout.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ConnectionTimeout.title },
            localized: { RuuviLocalization.Defaults.ConnectionTimeout.title($0) }),
        .init(
            key: "Defaults.DashboardTapActionChart.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.DashboardTapActionChart.title },
            localized: { RuuviLocalization.Defaults.DashboardTapActionChart.title($0) }),
        .init(
            key: "Defaults.DevServer.message", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.DevServer.message },
            localized: { RuuviLocalization.Defaults.DevServer.message($0) }),
        .init(
            key: "Defaults.DevServer.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.DevServer.title },
            localized: { RuuviLocalization.Defaults.DevServer.title($0) }),
        .init(
            key: "Defaults.HideNFC.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.HideNFC.title },
            localized: { RuuviLocalization.Defaults.HideNFC.title($0) }),
        .init(
            key: "Defaults.HistorySyncPerSensor.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.HistorySyncPerSensor.title },
            localized: { RuuviLocalization.Defaults.HistorySyncPerSensor.title($0) }),
        .init(
            key: "Defaults.ImageCompressionQuality.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ImageCompressionQuality.title },
            localized: { RuuviLocalization.Defaults.ImageCompressionQuality.title($0) }),
    ]
}
