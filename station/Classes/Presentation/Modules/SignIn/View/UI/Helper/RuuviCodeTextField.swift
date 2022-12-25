import Foundation
import UIKit

class RuuviCodeTextField: UITextField {
    weak var previousEntry: RuuviCodeTextField?
    weak var nextEntry: RuuviCodeTextField?

    override public func deleteBackward() {
        text = ""
        previousEntry?.becomeFirstResponder()
    }

}
