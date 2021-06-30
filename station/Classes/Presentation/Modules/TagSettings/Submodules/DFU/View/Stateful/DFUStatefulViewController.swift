import UIKit

enum DFUViewState {
    case checking
    case versions(latest: String)
    case downloading
    case listening
    case ready
    case flashing
    case success
}

final class DFUStatefulViewController: UIViewController {
    var output: DFUViewOutput!
    var state: DFUViewState = .checking

    override func viewDidLoad() {
        super.viewDidLoad()
        output.viewDidLoad()
    }
}

extension DFUStatefulViewController: DFUViewInput {
    func localize() {
    }
}
