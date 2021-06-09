import Foundation
import UIKit

protocol DfuFlashViewOutput: AnyObject {
    func viewDidLoad()
    func viewDidOpenDocumentPicker(sourceView: UIView)
    func viewDidCancelFlash()
    func viewDidStartFlash()
    func viewDidFinishFlash()
    func viewDidConfirmCancelFlash()
}
