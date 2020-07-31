import UIKit

class AddMacModalViewController: UIViewController {
    var output: AddMacModalViewOutput!
    var viewModel: AddMacModalViewModel!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        output.viewDidLoad()
    }
}

// MARK: - AddMacModalViewInput
extension AddMacModalViewController: AddMacModalViewInput {
    func localize() {
        title = "AddMacModal.Title.text".localized()
    }
}

// MARK: - Private
extension AddMacModalViewController {
}
