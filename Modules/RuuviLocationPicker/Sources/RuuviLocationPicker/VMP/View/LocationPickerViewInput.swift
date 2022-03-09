import Foundation
import UIKit
import RuuviOntology
import RuuviLocalization

protocol LocationPickerViewInput: UIViewController, Localizable {
    var selectedLocation: Location? { get set }
}
