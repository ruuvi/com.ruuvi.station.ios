import Foundation
import RuuviLocalization

struct ChartSettingsViewModel {
    let sections: [ChartSettingsSection]
}

struct ChartSettingsSection {
    let note: String?
    let cells: [ChartSettingsCell]
}

struct ChartSettingsCell {
    var type: ChartSettingsCellType
    var boolean: Observable<Bool?> = .init()
    var integer: Observable<Int?> = .init()
}

enum ChartSettingsIntegerUnit {
    case day
    case days

    var unitString: String {
        switch self {
        case .day:
            RuuviLocalization.Interval.Day.string
        case .days:
            RuuviLocalization.Interval.Days.string
        }
    }
}

enum ChartSettingsCellType {
    case disclosure(title: String)
    case stepper(
        title: String,
        value: Int,
        unitSingular: ChartSettingsIntegerUnit,
        unitPlural: ChartSettingsIntegerUnit
    )
    case switcher(title: String, value: Bool, hideStatusLabel: Bool)
}
