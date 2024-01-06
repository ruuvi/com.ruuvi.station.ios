import RuuviLocalization
import SwiftUI

enum OnboardPageType: Int {
    case measure = 0
    case dashboard = 1
    case sensors = 2
    case history = 3
    case alerts = 4
    case share = 5
    case widgets = 6
    case web = 7
    case signIn = 8
}

struct OnboardViewModel: Equatable {
    var pageType: OnboardPageType
    var title: String
    var subtitle: String
    var subSubtitle: String?
    var image: Image
    var hasContinue: Bool = false
}

// swiftlint:disable:next function_body_length
func buildOnboardingPages() -> [OnboardViewModel] {
    let meaureItem = OnboardViewModel(
        pageType: .measure,
        title: RuuviLocalization.onboardingMeasureYourWorld,
        subtitle: RuuviLocalization.onboardingWithRuuviSensors,
        subSubtitle: RuuviLocalization.onboardingSwipeToContinue,
        image: RuuviAsset.Onboarding.onboardingBeaverStart.swiftUIImage
    )

    let dashboardItem = OnboardViewModel(
        pageType: .dashboard,
        title: RuuviLocalization.onboardingDashboard,
        subtitle: RuuviLocalization.onboardingFollowMeasurement,
        image: RuuviAsset.Onboarding.onboardingDashboard.swiftUIImage
    )

    let sensorItem = OnboardViewModel(
        pageType: .sensors,
        title: RuuviLocalization.onboardingPersonalise,
        subtitle: RuuviLocalization.onboardingYourSensors,
        image: RuuviAsset.Onboarding.onboardingSensors.swiftUIImage
    )

    let historyItem = OnboardViewModel(
        pageType: .history,
        title: RuuviLocalization.onboardingHistory,
        subtitle: RuuviLocalization.onboardingExploreDetailed,
        image: RuuviAsset.Onboarding.onboardingHistory.swiftUIImage
    )

    let alertItem = OnboardViewModel(
        pageType: .alerts,
        title: RuuviLocalization.onboardingAlerts,
        subtitle: RuuviLocalization.onboardingSetCustom,
        image: RuuviAsset.Onboarding.onboardingAlerts.swiftUIImage
    )

    let shareItem = OnboardViewModel(
        pageType: .share,
        title: RuuviLocalization.onboardingShareesCanUse,
        subtitle: RuuviLocalization.onboardingShareYourSensors,
        image: RuuviAsset.Onboarding.onboardingShare.swiftUIImage
    )

    let widgetItem = OnboardViewModel(
        pageType: .widgets,
        title: RuuviLocalization.onboardingHandyWidgets,
        subtitle: RuuviLocalization.onboardingAccessWidgets,
        image: RuuviAsset.Onboarding.onboardingWidgets.swiftUIImage
    )

    let webItem = OnboardViewModel(
        pageType: .web,
        title: RuuviLocalization.onboardingStationWeb,
        subtitle: RuuviLocalization.onboardingWebPros,
        image: RuuviAsset.Onboarding.onboardingWeb.swiftUIImage
    )

    let signInItem = OnboardViewModel(
        pageType: .signIn,
        title: RuuviLocalization.onboardingThatsIt,
        subtitle: RuuviLocalization.onboardingGoToSignIn,
        image: RuuviAsset.Onboarding.onboardingBeaverSignIn.swiftUIImage,
        hasContinue: true
    )

    return [
        meaureItem,
        dashboardItem,
        sensorItem,
        historyItem,
        alertItem,
        shareItem,
        widgetItem,
        webItem,
        signInItem,
    ]
}
