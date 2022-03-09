import UIKit
import RuuviOntology

public protocol RuuviLocationPicker: AnyObject {
    var viewController: UIViewController { get }
    var router: AnyObject? { get set }
    var output: RuuviLocationPickerOutput? { get set }
}

public protocol RuuviLocationPickerOutput: AnyObject {
    func ruuviLocationPickerWantsClose(_ ruuviLocationPicker: RuuviLocationPicker)
    func ruuvi(locationPicker: RuuviLocationPicker, didPick location: Location)
}
