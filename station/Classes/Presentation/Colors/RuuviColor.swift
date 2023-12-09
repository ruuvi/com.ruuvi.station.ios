import SwiftUI

enum RuuviColor {
    static let purple = Color("RuuviPurple")
    static let green = Color("RuuviGreen")
    static let dustyBlue = Color("RuuviDustyBlue")
    static let ruuviPrimarySUI = UIColor(named: "RuuviPrimary")
    static let ruuviTintColorSUI = Color("RuuviTintColor")
    static let ruuviTextColorSUI = Color("RuuviTextColor")
    static let ruuviTitleTextColorSUI = Color("RuuviMenuTextColor")
    static let dashboardBGColor = UIColor(named: "RuuviDashboardBG")
    static let dashboardCardBGColor = UIColor(named: "RuuviDashboardCardBG")
    static let menuButtonTintColor = UIColor(named: "RuuviMenuTintColor")
    static let logoTintColor = UIColor(named: "RuuviLogoTintColor")
    static let dashboardIndicatorTextColor = UIColor(named: "RuuviDashboardIndicator")
    static let dashboardIndicatorBigTextColor = UIColor(named: "RuuviDashboardIndicatorBig")
    static let ruuviOrangeColor = UIColor(named: "RuuviOrangeColor")
    static let ruuviGraphBGColor = UIColor(named: "RuuviGraphBGColor")
    static let ruuviGraphFillColor = UIColor(named: "RuuviGraphFillColor")
    static let ruuviGraphLineColor = UIColor(named: "RuuviGraphFillColor")
    static let ruuviGraphMarkerColor = UIColor(named: "RuuviGraphMarkerColor")
    static let ruuviPrimary = UIColor(named: "RuuviPrimary")
    static let ruuviSecondary = UIColor(named: "RuuviSecondary")
    static let ruuviTintColor = UIColor(named: "RuuviTintColor")
    static let ruuviTextColor = UIColor(named: "RuuviTextColor")
    static let ruuviMenuTextColor = UIColor(named: "RuuviMenuTextColor")
    static let ruuviLineColor = UIColor(named: "RuuviLineColor")
    static let ruuviSwitchDisabledTint =
        UIColor(named: "RuuviSwitchDisabledTint")
    static let ruuviSwitchEnabledTint =
        UIColor(named: "RuuviSwitchEnabledTint")
    static let ruuviSwitchDisabledThumbTint = UIColor(named: "RuuviSwitchDisabledThumbTint")

    // Tag settings
    static let tagSettingsSectionHeaderColor = UIColor(named: "TagSettingsSectionHeaderColor")
    static let tagSettingsItemHeaderColor = UIColor(named: "TagSettingsItemHeaderColor")
}

extension RuuviColor {
    static let fallbackGraphLineColor = UIColor(hexString: "34ad9f")
    static let fallbackGraphFillColor = UIColor(hexString: "46cab9", alpha: 0.3)
}
