import Foundation
import RuuviOntology

protocol DFUModuleInput: AnyObject {
    var viewController: UIViewController { get }
    func configure(ruuviTag: RuuviTagSensor)
}
