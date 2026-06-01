import Foundation
import RuuviOntology

protocol UnitSettingsItemProtocol {
    var title: String { get }
}

enum UnitSettingsMode {
    case measurement
    case globalUnits
    case resolution
}

struct UnitSettingsViewModel {
    let title: String
    let items: [SelectionItemProtocol]
    let measurementType: MeasurementType
    let mode: UnitSettingsMode

    init(
        title: String,
        items: [SelectionItemProtocol],
        measurementType: MeasurementType,
        mode: UnitSettingsMode = .measurement
    ) {
        self.title = title
        self.items = items
        self.measurementType = measurementType
        self.mode = mode
    }
}
