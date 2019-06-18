import Foundation

enum ChartDataType {
    case rssi
}

protocol ChartModuleInput: class {
    func configure(ruuviTag: RuuviTagRealm, type: ChartDataType)
}
