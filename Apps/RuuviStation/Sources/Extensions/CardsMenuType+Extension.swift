import RuuviOntology
import RuuviLocalization
import UIKit

extension CardsMenuType {
    var icon: UIImage {
        switch self {
        case .measurement:
            return RuuviAsset.CardsMenu.iconMeasurement.image
        case .graph:
            return RuuviAsset.CardsMenu.iconGraph.image
        case .alerts:
            return RuuviAsset.CardsMenu.iconAlerts.image
        case .settings:
            return RuuviAsset.CardsMenu.iconSettings.image
        }
    }
}

extension CardsLegacyMenuType {
    var icon: UIImage {
        switch self {
        case .alerts:
            return RuuviAsset.CardsMenu.iconAlerts.image
        case .measurementGraph:
            return RuuviAsset.CardsMenu.iconGraph.image
        case .settings:
            return RuuviAsset.CardsMenu.iconSettings.image
        }
    }
}
