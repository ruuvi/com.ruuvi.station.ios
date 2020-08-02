import Foundation

protocol AddMacModalViewOutput {
    func viewDidLoad()
    func viewDidTriggerDismiss()
    func viewDidTriggerSend(mac: String)
}
