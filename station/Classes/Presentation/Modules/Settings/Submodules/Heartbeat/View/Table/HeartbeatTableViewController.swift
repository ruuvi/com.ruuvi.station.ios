import UIKit

class HeartbeatTableViewController: UITableViewController {

    var output: HeartbeatViewOutput!

    var viewModel = HeartbeatViewModel() {
        didSet {
            bindViewModel()
        }
    }

    @IBOutlet weak var bgScanningTitleLabel: UILabel!
    @IBOutlet weak var bgScanningSwitch: UISwitch!
    @IBOutlet weak var bgScanningIntervalTitleLabel: UILabel!
    @IBOutlet weak var bgScanningIntervalValueLabel: UILabel!
    @IBOutlet weak var bgScanningIntervalStepper: UIStepper!

    private let everyString = "Heartbeat.Interval.Every.string"
}

// MARK: - HeartbeatViewInput
extension HeartbeatTableViewController: HeartbeatViewInput {
    func localize() {
        bgScanningTitleLabel.text = viewModel.bgScanningTitle
        bgScanningIntervalTitleLabel.text = viewModel.bgScanningIntervalTitle
        if viewModel.bgScanningInterval.value.bound > 0 {
            bgScanningIntervalValueLabel.text = everyString.localized()
                + " " + "\(viewModel.bgScanningInterval.value.bound)"
                + " " + "Heartbeat.Interval.Min.string".localized()
        } else {
            bgScanningIntervalValueLabel.text = "Heartbeat.Interval.All.string".localized()
        }
    }
}

// MARK: - IBActions
extension HeartbeatTableViewController {
    @IBAction func bgScanningIntervalStepperValueChanged(_ sender: Any) {
        viewModel.bgScanningInterval.value = Int(bgScanningIntervalStepper.value)
    }

    @IBAction func bgScanningSwitchValueChanged(_ sender: Any) {
        viewModel.bgScanningState.value = bgScanningSwitch.isOn
    }
}

// MARK: - View lifecycle
extension HeartbeatTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        bindViewModel()
    }
}

// MARK: - Private
extension HeartbeatTableViewController {

    private func bindViewModel() {
        if isViewLoaded {

            bgScanningSwitch.bind(viewModel.bgScanningState) { (view, isOn) in
                view.isOn = isOn.bound
            }
            let every = everyString
            bgScanningIntervalValueLabel.bind(viewModel.bgScanningInterval) { (label, interval) in
                if interval.bound > 0 {
                    label.text = every.localized()
                                + " " + "\(interval.bound)"
                                + " " + "Heartbeat.Interval.Min.string".localized()
                } else {
                    label.text = "Heartbeat.Interval.All.string".localized()
                }
            }
            bgScanningIntervalStepper.bind(viewModel.bgScanningInterval) { (stepper, interval) in
                stepper.value = Double(interval.bound)
            }
        }
    }

}
