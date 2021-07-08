import Foundation
import UIKit
import RuuviOntology

protocol DFUModuleInput: AnyObject {
    var viewController: UIViewController { get }

    func isSafeToDismiss() -> Bool
}
