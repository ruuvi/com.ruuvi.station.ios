import Foundation
import RuuviOntology

protocol LocationPickerViewInput: ViewInput {
    var selectedLocation: Location? { get set }
}
