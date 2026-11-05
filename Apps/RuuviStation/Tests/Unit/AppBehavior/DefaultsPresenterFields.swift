import RuuviLocalization
import XCTest
@testable import station

struct DefaultsIntegerField {
    let title: String
    let key: ReferenceWritableKeyPath<AppTestSettings, Int>
    let unit: DefaultsIntegerUnit
    init(_ title: String, _ key: ReferenceWritableKeyPath<AppTestSettings, Int>, _ unit: DefaultsIntegerUnit) {
        self.title = title
        self.key = key
        self.unit = unit
    }
}

extension DefaultsPresenterTests {
    var booleanSettings: [(String, ReferenceWritableKeyPath<AppTestSettings, Bool>, Bool)] {
        [
            (RuuviLocalization.Defaults.WelcomeShown.title, \.welcomeShown, true),
            (RuuviLocalization.Defaults.TOSAccepted.title, \.tosAccepted, true),
            (
                RuuviLocalization.Defaults.ChartsSwipeInstructionWasShown.title,
                \.tagChartsLandscapeSwipeInstructionWasShown, true
            ),
            ("Show graph long press instruction", \.showGraphLongPressTutorial, true),
            (RuuviLocalization.Defaults.CardsSwipeHint.title, \.cardsSwipeHintWasShown, true),
            (RuuviLocalization.Defaults.HideNFC.title, \.hideNFCForSensorContest, true),
            (RuuviLocalization.Defaults.ShowStatusLabelSettings.title, \.showSwitchStatusLabel, false),
            (RuuviLocalization.Defaults.ShowAlertRangeInCharts.title, \.showAlertsRangeInGraph, false),
            (RuuviLocalization.Defaults.UseNewChart.title, \.useNewGraphRendering, false),
            (RuuviLocalization.Defaults.HistorySyncPerSensor.title, \.historySyncForEachSensor, false),
            (
                RuuviLocalization.Defaults.IncludeDataSourceInHistoryExport.title, \.includeDataSourceInHistoryExport,
                false
            ),
        ]
    }

    var booleanFlags: [(String, ReferenceWritableKeyPath<AppTestFlags, Bool>)] {
        [
            ("Show new Cards Settings", \.showNewSettings),
            ("Download Beta Firmware", \.downloadBetaFirmware),
            ("Download Alpha Firmware (This overrides above settings)", \.downloadAlphaFirmware),
            ("Auto sync Ruuvi Air GATT history on graph open", \.autoSyncGattHistoryForRuuviAir),
            ("Allow multiple sensors GATT sync", \.allowConcurrentGattSyncForMultipleSensors),
            ("Show marketing preference", \.showMarketingPreference),
            ("Show dashboard sensor search", \.showDashboardSensorSearch),
        ]
    }

    var integerSettings: [DefaultsIntegerField] {
        [
            .init(RuuviLocalization.Defaults.AlertsMuteInterval.title, \.alertsMuteIntervalMinutes, .minutes),
            .init(RuuviLocalization.Defaults.WebPullInterval.title, \.webPullIntervalMinutes, .minutes),
            .init(RuuviLocalization.Defaults.NetworkPullingInterval.title, \.networkPullIntervalSeconds, .seconds),
            .init(RuuviLocalization.Defaults.WidgetsRefreshInterval.title, \.widgetRefreshIntervalMinutes, .minutes),
            .init(RuuviLocalization.Defaults.PruningOffsetHours.title, \.dataPruningOffsetHours, .hours),
            .init(RuuviLocalization.Defaults.ChartIntervalSeconds.title, \.chartIntervalSeconds, .seconds),
            .init(RuuviLocalization.Defaults.ChartDurationHours.title, \.chartDurationHours, .hours),
            .init(
                RuuviLocalization.Defaults.BackgroundScanning.Foreground.interval,
                \.saveHeartbeatsForegroundIntervalSeconds, .seconds),
            .init(RuuviLocalization.Defaults.ImageCompressionQuality.title, \.imageCompressionQuality, .decimal),
            .init(RuuviLocalization.ForegroundRow.Advertisement.title, \.advertisementDaemonIntervalMinutes, .minutes),
            .init("Movement alert blink hysteresis", \.movementAlertHysteresisMinutes, .minutes),
            .init(
                RuuviLocalization.Defaults.AppLaunchRequiredForReview.Count.title, \.appOpenedInitialCountToAskReview,
                .decimal),
            .init(
                RuuviLocalization.Defaults.AskReviewIfLaunchDivisibleBy.Count.title,
                \.appOpenedCountDivisibleToAskReview, .decimal),
        ]
    }
}
