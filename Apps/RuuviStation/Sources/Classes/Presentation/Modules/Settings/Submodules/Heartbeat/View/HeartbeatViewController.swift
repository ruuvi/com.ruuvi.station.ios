import RuuviLocalization
import UIKit

class HeartbeatViewController: UIViewController {
    var output: HeartbeatViewOutput!

    var viewModel = HeartbeatViewModel() {
        didSet {
            table?.viewModel = viewModel
        }
    }

    private var table: HeartbeatTableViewController?

    private lazy var confirmBackgroundScanningDisable: (@escaping (Bool) -> Void) -> Void = { [weak self] completion in
        guard let self else { return }
        let alert = UIAlertController(
            title: nil,
            message: RuuviLocalization.Settings.BackgroundScanning.DisableConfirmation.message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel) { _ in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: RuuviLocalization.confirm, style: .default) { _ in
            completion(true)
        })
        present(alert, animated: true)
    }
}

extension HeartbeatViewController: HeartbeatViewInput {
    func localize() {
        navigationItem.title = RuuviLocalization.Settings.BackgroundScanning.title
    }
}

// MARK: - View lifecycle

extension HeartbeatViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        styleViews()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        switch segue.identifier {
        case HeartbeatEmbedSegue.table.rawValue:
            table = segue.destination as? HeartbeatTableViewController
            table?.output = output
            table?.viewModel = viewModel
            table?.confirmBackgroundScanningDisable = confirmBackgroundScanningDisable
        default:
            break
        }
    }
}
