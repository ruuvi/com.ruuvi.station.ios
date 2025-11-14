import Foundation
import SwiftUI

// MARK: - Section Models
protocol TitledSection: Identifiable {
    var title: String { get }
}

struct SettingsSection: Identifiable {
    let id: String
    let title: String
    let isCollapsible: Bool
    let content: () -> AnyView

    init(
        id: String,
        title: String,
        isCollapsible: Bool = true,
        content: @escaping () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.isCollapsible = isCollapsible
        self.content = content
    }
}

extension SettingsSection: TitledSection {}




//
//protocol TitledSection: Identifiable {
//    var title: String { get }
//}
//
////struct AlertSection: TitledSection {
////    let id: String
////    let title: String
////    let type: SensorAlertType
////    let identifier: TagSettingsSectionIdentifier
////}
//
//struct SettingsSection: TitledSection {
//    let id: String
//    let title: String
//    let type: SettingsSectionType
//    let identifier: TagSettingsSectionIdentifier
//}
//
//enum SettingsSectionType {
//    case offsetCorrection
//    case moreInfo
//    case firmware
//    case remove
//
//    var identifier: String {
//        switch self {
//        case .offsetCorrection: return "offsetCorrection"
//        case .moreInfo: return "moreInfo"
//        case .firmware: return "firmware"
//        case .remove: return "remove"
//        }
//    }
//}
//
//enum SensorAlertType: CaseIterable {
//    case airQuality
//    case co2
//    case pm1
//    case pm25
//    case pm4
//    case pm10
//    case voc
//    case nox
//    case temperature
//    case humidity
//    case pressure
//    case luminosity
//    case movement
//    case sound
//    case signalStrength
//    case connection
//    case cloudConnection
//
//    var identifier: String {
//        switch self {
//        case .airQuality: return "airQuality"
//        case .co2: return "co2"
//        case .pm1: return "pm1"
//        case .pm25: return "pm25"
//        case .pm4: return "pm4"
//        case .pm10: return "pm10"
//        case .voc: return "voc"
//        case .nox: return "nox"
//        case .temperature: return "temperature"
//        case .humidity: return "humidity"
//        case .pressure: return "pressure"
//        case .luminosity: return "luminosity"
//        case .movement: return "movement"
//        case .sound: return "sound"
//        case .signalStrength: return "signalStrength"
//        case .connection: return "connection"
//        case .cloudConnection: return "cloudConnection"
//        }
//    }
//
//    var alertPrototype: AlertType {
//        switch self {
//        case .airQuality: return .aqi(lower: 0, upper: 0)
//        case .co2: return .carbonDioxide(lower: 0, upper: 0)
//        case .pm1: return .pMatter1(lower: 0, upper: 0)
//        case .pm25: return .pMatter25(lower: 0, upper: 0)
//        case .pm4: return .pMatter4(lower: 0, upper: 0)
//        case .pm10: return .pMatter10(lower: 0, upper: 0)
//        case .voc: return .voc(lower: 0, upper: 0)
//        case .nox: return .nox(lower: 0, upper: 0)
//        case .temperature: return .temperature(lower: 0, upper: 0)
//        case .humidity: return .relativeHumidity(lower: 0, upper: 0)
//        case .pressure: return .pressure(lower: 0, upper: 0)
//        case .luminosity: return .luminosity(lower: 0, upper: 0)
//        case .movement: return .movement(last: 0)
//        case .sound: return .soundInstant(lower: 0, upper: 0)
//        case .signalStrength: return .signal(lower: 0, upper: 0)
//        case .connection: return .connection
//        case .cloudConnection: return .cloudConnection(unseenDuration: 0)
//        }
//    }
//
//    var identifierForState: TagSettingsSectionIdentifier {
//        .alerts(alertPrototype)
//    }
//}
