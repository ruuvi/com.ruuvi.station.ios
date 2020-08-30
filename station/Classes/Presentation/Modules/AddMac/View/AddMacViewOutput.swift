import Foundation

protocol AddMacViewOutput {
    func viewDidLoad()
    func viewDidTriggerDismiss()
    func viewDidTriggerSend(mac: String)
}
