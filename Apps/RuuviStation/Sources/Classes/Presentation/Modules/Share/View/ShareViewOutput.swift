import Foundation

protocol ShareViewOutput {
    func viewDidLoad()
    func viewDidTapSendButton(email: String?)
    func viewDidTapUnshareEmail(_ email: String?)
}
