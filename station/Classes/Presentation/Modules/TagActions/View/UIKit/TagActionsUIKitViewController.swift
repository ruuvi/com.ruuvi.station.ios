import UIKit

class TagActionsUIKitViewController: UIViewController {
    var output: TagActionsViewOutput!
    var viewModel: TagActionsViewModel!
}

// MARK: - TagActionsViewInput
extension TagActionsUIKitViewController: TagActionsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - View lifecycle
extension TagActionsUIKitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
    }
}

