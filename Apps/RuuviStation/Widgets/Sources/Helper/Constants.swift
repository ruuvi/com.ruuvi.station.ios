import Foundation

public enum Constants: String {
    case appGroupBundleId = "group.com.ruuvi.station.widgets"

    case ruuviCloudBaseURL = "https://network.ruuvi.com"
    case ruuviCloudBaseURLDev = "https://j9ul2pfmol.execute-api.eu-central-1.amazonaws.com"

    case simpleWidgetKindId = "ruuvi.simpleWidget"
    case simpleWidgetDisplayName = "Ruuvi Widget"

    case isAuthorizedUDKey = "RuuviUserCoordinator.isAuthorizedUDKey"
    case hasCloudSensorsKey
    case languageKey
    case temperatureUnitKey
    case temperatureAccuracyKey
    case humidityUnitKey
    case humidityAccuracyKey
    case pressureUnitKey
    case pressureAccuracyKey
    case useDevServerKey

    case ruuviLogo = "ruuvi_logo"
    case ruuviLogoEye = "eye_circle"

    case muliRegular = "Muli-Regular"
    case muliBold = "Muli-Bold"
    case oswaldBold = "Oswald-Bold"
    case oswaldExtraLight = "Oswald-ExtraLight"
}
