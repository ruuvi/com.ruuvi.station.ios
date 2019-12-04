import UIKit

class HeartbeatTableViewController: UITableViewController {

    var output: HeartbeatViewOutput!

    var viewModel = HeartbeatViewModel() {
        didSet {
            bindViewModel()
        }
    }

}

extension HeartbeatTableViewController {

    private func bindViewModel() {
        
    }

}
