import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviUser
import WidgetKit

class DefaultsPresenter: NSObject, DefaultsModuleInput {
    weak var view: DefaultsViewInput!
    var router: DefaultsRouterInput!
    var settings: RuuviLocalSettings!
    var ruuviUser: RuuviUser!
    var output: DefaultsModuleOutput?

    let appGroupDefaults = UserDefaults(
        suiteName: AppGroupConstants.appGroupSuiteIdentifier
    )

    func configure(output: DefaultsModuleOutput) {
        view.viewModels = [
            buildWelcomeShown(),
            buildChartsSwipeInstruction(),
            buildConnectionTimeout(),
            buildServiceTimeout(),
            buildCardsSwipeHint(),
            buildAlertsMuteInterval(),
            buildWebPullInterval(),
            buildPruningOffsetHours(),
            buildChartIntervalSeconds(),
            buildChartDurationHours(),
            saveAdvertisementsInterval(),
            buildAskForReviewFirstTime(),
            buildAskForReviewLater(),
            buildDashboardCardTapAction(),
            buildConnectToDevServer(),
            buildHideNFCButtonInSensorContents(),
            buildIsAuthorized(),
            buildAuthToken(),
            buildShowEmailAlertSettings(),
            buildShowPushAlertSettings(),
            buildIsAuthorized(),
        ]
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss()
        completion?()
    }
}

// MARK: - DefaultsViewOutput

extension DefaultsPresenter: DefaultsViewOutput {
    func viewDidTriggerUseDevServer(useDevServer: Bool?) {
        changeRuuviCloudEndpoint(useDevServer: useDevServer)
    }
}

// MARK: Private

extension DefaultsPresenter {
    private func buildWelcomeShown() -> DefaultsViewModel {
        let welcomeShown = DefaultsViewModel()
        welcomeShown.title = RuuviLocalization.Defaults.WelcomeShown.title
        welcomeShown.boolean.value = settings.welcomeShown
        welcomeShown.type.value = .switcher

        bind(welcomeShown.boolean, fire: false) { observer, welcomeShown in
            observer.settings.welcomeShown = welcomeShown.bound
        }
        return welcomeShown
    }

    private func buildChartsSwipeInstruction() -> DefaultsViewModel {
        let tagChartsLandscapeSwipeInstructionWasShown = DefaultsViewModel()
        tagChartsLandscapeSwipeInstructionWasShown.title
            = RuuviLocalization.Defaults.ChartsSwipeInstructionWasShown.title
        tagChartsLandscapeSwipeInstructionWasShown.boolean.value
            = settings.tagChartsLandscapeSwipeInstructionWasShown
        tagChartsLandscapeSwipeInstructionWasShown.type.value = .switcher

        bind(tagChartsLandscapeSwipeInstructionWasShown.boolean, fire: false) {
            observer, tagChartsLandscapeSwipeInstructionWasShown in
            observer.settings.tagChartsLandscapeSwipeInstructionWasShown =
                tagChartsLandscapeSwipeInstructionWasShown.bound
        }
        return tagChartsLandscapeSwipeInstructionWasShown
    }

    private func buildConnectionTimeout() -> DefaultsViewModel {
        let connectionTimeout = DefaultsViewModel()
        connectionTimeout.title = RuuviLocalization.Defaults.ConnectionTimeout.title
        connectionTimeout.integer.value = Int(settings.connectionTimeout)
        connectionTimeout.type.value = .stepper
        connectionTimeout.unit = .seconds

        bind(connectionTimeout.integer, fire: false) { observer, connectionTimeout in
            observer.settings.connectionTimeout = TimeInterval(connectionTimeout.bound)
        }
        return connectionTimeout
    }

    private func buildServiceTimeout() -> DefaultsViewModel {
        let serviceTimeout = DefaultsViewModel()
        serviceTimeout.title = RuuviLocalization.Defaults.ServiceTimeout.title
        serviceTimeout.integer.value = Int(settings.serviceTimeout)
        serviceTimeout.type.value = .stepper
        serviceTimeout.unit = .seconds

        bind(serviceTimeout.integer, fire: false) { observer, serviceTimeout in
            observer.settings.serviceTimeout = TimeInterval(serviceTimeout.bound)
        }
        return serviceTimeout
    }

    private func buildCardsSwipeHint() -> DefaultsViewModel {
        let cardsSwipeHint = DefaultsViewModel()
        cardsSwipeHint.title = RuuviLocalization.Defaults.CardsSwipeHint.title
        cardsSwipeHint.boolean.value = settings.cardsSwipeHintWasShown
        cardsSwipeHint.type.value = .switcher

        bind(cardsSwipeHint.boolean, fire: false) { observer, cardsSwipeHintWasShown in
            observer.settings.cardsSwipeHintWasShown = cardsSwipeHintWasShown.bound
        }
        return cardsSwipeHint
    }

    private func buildAlertsMuteInterval() -> DefaultsViewModel {
        let alertsInterval = DefaultsViewModel()
        alertsInterval.title = RuuviLocalization.Defaults.AlertsMuteInterval.title
        alertsInterval.integer.value = settings.alertsMuteIntervalMinutes
        alertsInterval.unit = .minutes
        alertsInterval.type.value = .stepper

        bind(alertsInterval.integer, fire: false) { observer, alertsInterval in
            observer.settings.alertsMuteIntervalMinutes = alertsInterval.bound
        }
        return alertsInterval
    }

    private func buildWebPullInterval() -> DefaultsViewModel {
        let webPullInterval = DefaultsViewModel()
        webPullInterval.title = RuuviLocalization.Defaults.WebPullInterval.title
        webPullInterval.integer.value = settings.webPullIntervalMinutes
        webPullInterval.unit = .minutes
        webPullInterval.type.value = .stepper

        bind(webPullInterval.integer, fire: false) { observer, webPullInterval in
            observer.settings.webPullIntervalMinutes = webPullInterval.bound
        }
        return webPullInterval
    }

    private func buildPruningOffsetHours() -> DefaultsViewModel {
        let pruningOffsetHours = DefaultsViewModel()
        pruningOffsetHours.title = RuuviLocalization.Defaults.PruningOffsetHours.title
        pruningOffsetHours.integer.value = settings.dataPruningOffsetHours
        pruningOffsetHours.unit = .hours
        pruningOffsetHours.type.value = .stepper

        bind(pruningOffsetHours.integer, fire: false) { observer, pruningOffsetHours in
            observer.settings.dataPruningOffsetHours = pruningOffsetHours.bound
        }
        return pruningOffsetHours
    }

    private func buildChartIntervalSeconds() -> DefaultsViewModel {
        let chartIntervalSeconds = DefaultsViewModel()
        chartIntervalSeconds.title = RuuviLocalization.Defaults.ChartIntervalSeconds.title
        chartIntervalSeconds.integer.value = settings.chartIntervalSeconds
        chartIntervalSeconds.unit = .seconds
        chartIntervalSeconds.type.value = .stepper

        bind(chartIntervalSeconds.integer, fire: false) { observer, chartIntervalSeconds in
            observer.settings.chartIntervalSeconds = chartIntervalSeconds.bound
        }
        return chartIntervalSeconds
    }

    private func buildChartDurationHours() -> DefaultsViewModel {
        let chartDurationHours = DefaultsViewModel()
        chartDurationHours.title = RuuviLocalization.Defaults.ChartDurationHours.title
        chartDurationHours.integer.value = settings.chartDurationHours
        chartDurationHours.unit = .hours
        chartDurationHours.type.value = .stepper

        bind(chartDurationHours.integer, fire: false) { observer, chartDurationHours in
            observer.settings.chartDurationHours = chartDurationHours.bound
        }
        return chartDurationHours
    }

    private func saveAdvertisementsInterval() -> DefaultsViewModel {
        let advertisementInterval = DefaultsViewModel()
        advertisementInterval.title = RuuviLocalization.ForegroundRow.Advertisement.title
        advertisementInterval.integer.value = settings.advertisementDaemonIntervalMinutes
        advertisementInterval.unit = .minutes
        advertisementInterval.type.value = .stepper

        bind(advertisementInterval.integer, fire: false) { observer, interval in
            observer.settings.advertisementDaemonIntervalMinutes = interval.bound
        }
        return advertisementInterval
    }

    private func buildAskForReviewFirstTime() -> DefaultsViewModel {
        let askForReviewAtLaunch = DefaultsViewModel()
        askForReviewAtLaunch.title = RuuviLocalization.Defaults.AppLaunchRequiredForReview.Count.title
        askForReviewAtLaunch.integer.value = settings.appOpenedInitialCountToAskReview
        askForReviewAtLaunch.unit = .decimal
        askForReviewAtLaunch.type.value = .stepper

        bind(askForReviewAtLaunch.integer, fire: false) { observer, interval in
            observer.settings.appOpenedInitialCountToAskReview = interval.bound
        }
        return askForReviewAtLaunch
    }

    private func buildAskForReviewLater() -> DefaultsViewModel {
        let askForReviewAtLaunch = DefaultsViewModel()
        askForReviewAtLaunch.title = RuuviLocalization.Defaults.AskReviewIfLaunchDivisibleBy.Count.title
        askForReviewAtLaunch.integer.value = settings.appOpenedCountDivisibleToAskReview
        askForReviewAtLaunch.unit = .decimal
        askForReviewAtLaunch.type.value = .stepper

        bind(askForReviewAtLaunch.integer, fire: false) { observer, interval in
            observer.settings.appOpenedCountDivisibleToAskReview = interval.bound
        }
        return askForReviewAtLaunch
    }

    private func buildIsAuthorized() -> DefaultsViewModel {
        let viewModel = DefaultsViewModel()
        viewModel.title = RuuviLocalization.Defaults.UserAuthorized.title
        viewModel.type.value = .plain
        viewModel.value.value = ruuviUser.isAuthorized ? RuuviLocalization.yes : RuuviLocalization.no
        return viewModel
    }

    private func buildAuthToken() -> DefaultsViewModel {
        let viewModel = DefaultsViewModel()
        viewModel.title = "Auth Token"
        viewModel.type.value = .plain
        viewModel.value.value = ruuviUser.apiKey
        return viewModel
    }

    private func buildDashboardCardTapAction() -> DefaultsViewModel {
        let viewModel = DefaultsViewModel()
        viewModel.title = RuuviLocalization.Defaults.DashboardTapActionChart.title
        viewModel.boolean.value = settings.dashboardTapActionType == .chart
        viewModel.type.value = .switcher

        bind(viewModel.boolean, fire: false) { observer, showChart in
            if let showChart {
                observer.settings.dashboardTapActionType = showChart ? .chart : .card
            }
        }
        return viewModel
    }

    private func buildConnectToDevServer() -> DefaultsViewModel {
        let useDevServer = appGroupDefaults?.bool(
            forKey: AppGroupConstants.useDevServerKey
        ) ?? false

        let viewModel = DefaultsViewModel()
        viewModel.title = RuuviLocalization.Defaults.DevServer.title
        viewModel.boolean.value = useDevServer
        viewModel.type.value = .switcher

        // This is a different settings than all other local settings.
        // We will store this into the app group prefs so that it can be accessed
        // in the widgets too.
        // This also has to be loaded in the AppAssembly. So, we can't really use
        // local settings module for this since we load the whole Local settings in
        // the AppAssembly.
        bind(
            viewModel.boolean,
            fire: false
        ) { [weak self] _, useDevServer in
            self?.view
                .showEndpointChangeConfirmationDialog(
                    useDevServer: useDevServer
                )
        }
        return viewModel
    }

    private func buildHideNFCButtonInSensorContents() -> DefaultsViewModel {
        let viewModel = DefaultsViewModel()
        viewModel.title = RuuviLocalization.Defaults.HideNFC.title
        viewModel.boolean.value = settings.hideNFCForSensorContest
        viewModel.type.value = .switcher

        bind(
            viewModel.boolean,
            fire: false
        ) { observer, hideNFC in
            observer.settings.hideNFCForSensorContest = hideNFC.bound
        }
        return viewModel
    }

    private func buildShowEmailAlertSettings() -> DefaultsViewModel {
        let viewModel = DefaultsViewModel()
        viewModel.title = RuuviLocalization.Defaults.ShowEmailAlertsSettings.title
        viewModel.boolean.value = settings.showEmailAlertSettings
        viewModel.type.value = .switcher

        bind(viewModel.boolean, fire: false) { observer, show in
            observer.settings.showEmailAlertSettings = GlobalHelpers.getBool(from: show)
        }

        return viewModel
    }

    private func buildShowPushAlertSettings() -> DefaultsViewModel {
        let viewModel = DefaultsViewModel()
        viewModel.title = RuuviLocalization.Defaults.ShowPushAlertsSettings.title
        viewModel.boolean.value = settings.showPushAlertSettings
        viewModel.type.value = .switcher

        bind(viewModel.boolean, fire: false) { observer, show in
            observer.settings.showPushAlertSettings = GlobalHelpers.getBool(from: show)
        }

        return viewModel
    }
}

extension DefaultsPresenter {
    private func changeRuuviCloudEndpoint(useDevServer: Bool?) {
        appGroupDefaults?.set(
            useDevServer,
            forKey: AppGroupConstants.useDevServerKey
        )
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
        NotificationCenter
            .default
            .post(
                name: .NetworkSyncDidFailForAuthorization,
                object: self,
                userInfo: nil
            )
        output?.defaultsModuleDidDismiss(module: self)
    }
}
