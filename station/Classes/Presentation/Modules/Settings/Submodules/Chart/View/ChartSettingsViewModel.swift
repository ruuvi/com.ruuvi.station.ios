import Foundation

struct ChartSettingsViewModel {
    let sections: [ChartSettingsSection]
}

struct ChartSettingsSection {
    let note: String?
    let cells: [ChartSettingsCell]
}

struct ChartSettingsCell {
    var type: ChartSettingsCellType
    var boolean: Observable<Bool?> = Observable<Bool?>()
    var integer: Observable<Int?> = Observable<Int?>()
}

enum ChartSettingsIntegerUnit {
    case day
    case days

    var unitString: String {
        switch self {
        case .day:
            return "Interval.Day.string".localized()
        case .days:
            return "Interval.Days.string".localized()
        }
    }
}

enum ChartSettingsCellType {
    case disclosure(title: String)
    case stepper(title: String,
                 value: Int,
                 unitSingular: ChartSettingsIntegerUnit,
                 unitPlural: ChartSettingsIntegerUnit)
    case switcher(title: String, value: Bool)
}
