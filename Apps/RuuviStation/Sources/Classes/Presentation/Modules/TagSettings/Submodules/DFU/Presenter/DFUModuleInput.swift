import Foundation
import RuuviOntology
import UIKit

protocol DFUModuleInput: AnyObject {
    var viewController: UIViewController { get }
    var output: DFUModuleOutput? { get set }
    func isSafeToDismiss() -> Bool
}

protocol DFUModuleOutput: AnyObject {
    func dfuModuleSuccessfullyUpgraded(_ dfuModule: DFUModuleInput)
}
