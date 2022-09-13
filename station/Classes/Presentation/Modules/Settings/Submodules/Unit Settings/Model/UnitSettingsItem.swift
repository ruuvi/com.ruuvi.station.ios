import Foundation

protocol UnitSettingsItemProtocol {
    var title: String { get }
}

struct UnitSettingsViewModel {
    let title: String
    let items: [SelectionItemProtocol]
    let measurementType: MeasurementType
}
