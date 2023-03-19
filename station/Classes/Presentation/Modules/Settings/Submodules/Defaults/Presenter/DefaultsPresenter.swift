import Foundation
import RuuviLocal
import RuuviUser

class DefaultsPresenter: NSObject, DefaultsModuleInput {
    weak var view: DefaultsViewInput!
    var router: DefaultsRouterInput!
    var settings: RuuviLocalSettings!
    var ruuviUser: RuuviUser!

    func configure() {
        view.viewModels = [buildWelcomeShown(),
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
                           buildSaveAndLoadFromWebIntervalMinutues(),
                           buildAskForReviewFirstTime(),
                           buildAskForReviewLater(),
                           buildIsAuthorized(),
                           buildAuthToken(),
                           buildDashboardCardTapAction()]
    }
}

// MARK: - DefaultsViewOutput
extension DefaultsPresenter: DefaultsViewOutput {

}

// MARK: Private
extension DefaultsPresenter {
    private func buildWelcomeShown() -> DefaultsViewModel {
        let welcomeShown = DefaultsViewModel()
        welcomeShown.title = "Defaults.WelcomeShown.title".localized()
        welcomeShown.boolean.value = settings.welcomeShown
        welcomeShown.type.value = .switcher

        bind(welcomeShown.boolean, fire: false) { observer, welcomeShown in
            observer.settings.welcomeShown = welcomeShown.bound
        }
        return welcomeShown
    }

    private func buildChartsSwipeInstruction() -> DefaultsViewModel {
        let tagChartsLandscapeSwipeInstructionWasShown = DefaultsViewModel()
        tagChartsLandscapeSwipeInstructionWasShown.title = "Defaults.ChartsSwipeInstructionWasShown.title".localized()
        tagChartsLandscapeSwipeInstructionWasShown.boolean.value = settings.tagChartsLandscapeSwipeInstructionWasShown
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
        connectionTimeout.title = "Defaults.ConnectionTimeout.title".localized()
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
        serviceTimeout.title = "Defaults.ServiceTimeout.title".localized()
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
        cardsSwipeHint.title = "Defaults.CardsSwipeHint.title".localized()
        cardsSwipeHint.boolean.value = settings.cardsSwipeHintWasShown
        cardsSwipeHint.type.value = .switcher

        bind(cardsSwipeHint.boolean, fire: false) { observer, cardsSwipeHintWasShown in
            observer.settings.cardsSwipeHintWasShown = cardsSwipeHintWasShown.bound
        }
        return cardsSwipeHint
    }

    private func buildAlertsMuteInterval() -> DefaultsViewModel {
        let alertsInterval = DefaultsViewModel()
        alertsInterval.title = "Defaults.AlertsMuteInterval.title".localized()
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
        webPullInterval.title = "Defaults.WebPullInterval.title".localized()
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
        pruningOffsetHours.title = "Defaults.PruningOffsetHours.title".localized()
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
        chartIntervalSeconds.title = "Defaults.ChartIntervalSeconds.title".localized()
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
        chartDurationHours.title = "Defaults.ChartDurationHours.title".localized()
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
        advertisementInterval.title = "ForegroundRow.advertisement.title".localized()
        advertisementInterval.integer.value = settings.advertisementDaemonIntervalMinutes
        advertisementInterval.unit = .minutes
        advertisementInterval.type.value = .stepper

        bind(advertisementInterval.integer, fire: false) { observer, interval in
            observer.settings.advertisementDaemonIntervalMinutes = interval.bound
        }
        return advertisementInterval
    }

    private func buildSaveAndLoadFromWebIntervalMinutues() -> DefaultsViewModel {
        let webSaveAndLoadInterval = DefaultsViewModel()
        webSaveAndLoadInterval.title = "ForegroundRow.webTags.title".localized()
        webSaveAndLoadInterval.integer.value = settings.webTagDaemonIntervalMinutes
        webSaveAndLoadInterval.unit = .minutes
        webSaveAndLoadInterval.type.value = .stepper

        bind(webSaveAndLoadInterval.integer, fire: false) { observer, interval in
            observer.settings.webTagDaemonIntervalMinutes = interval.bound
        }
        return webSaveAndLoadInterval
    }

    private func buildAskForReviewFirstTime() -> DefaultsViewModel {
        let askForReviewAtLaunch = DefaultsViewModel()
        askForReviewAtLaunch.title = "Defaults.AppLaunchRequiredForReview.Count.title".localized()
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
        askForReviewAtLaunch.title = "Defaults.AskReviewIfLaunchDivisibleBy.Count.title".localized()
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
        viewModel.title = "User Authorized"
        viewModel.type.value = .plain
        viewModel.value.value = ruuviUser.isAuthorized ? "Yes" : "No"
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
        viewModel.title = "Show Chart on Dashboard Card Tap"
        viewModel.boolean.value = settings.showChartOnDashboardCardTap
        viewModel.type.value = .switcher

        bind(viewModel.boolean, fire: false) { observer, showChart in
            observer.settings.showChartOnDashboardCardTap = showChart.bound
        }
        return viewModel
    }

}
