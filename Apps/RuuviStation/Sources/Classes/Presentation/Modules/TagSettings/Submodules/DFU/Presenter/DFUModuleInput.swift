import Foundation
import RuuviOntology
import UIKit

protocol DFUModuleInput: AnyObject {
    var viewController: UIViewController { get }

    func isSafeToDismiss() -> Bool
}
