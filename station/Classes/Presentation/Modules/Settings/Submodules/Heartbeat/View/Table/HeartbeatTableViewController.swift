import UIKit

class HeartbeatTableViewController: UITableViewController {

    var output: HeartbeatViewOutput!

    var viewModel = HeartbeatViewModel() {
        didSet {
            bindViewModel()
        }
    }

    @IBOutlet weak var saveHeartbeatsTitleLabel: UILabel!
    @IBOutlet weak var saveHeartbeatsSwitch: UISwitch!
    @IBOutlet weak var saveHeartbeatsIntervalLabel: UILabel!
    @IBOutlet weak var saveHeartbeatsIntervalStepper: UIStepper!
    @IBOutlet weak var readRSSITitleLabel: UILabel!
    @IBOutlet weak var readRSSISwitch: UISwitch!
    @IBOutlet weak var readRSSIIntervalLabel: UILabel!
    @IBOutlet weak var readRSSIIntervalStepper: UIStepper!

    private let everyString = "Heartbeat.Interval.Every.string"
}

// MARK: - HeartbeatViewInput
extension HeartbeatTableViewController: HeartbeatViewInput {
    func localize() {
        saveHeartbeatsTitleLabel.text = viewModel.saveHeartbeatsTitle
        if viewModel.saveHeartbeatsInterval.value.bound > 0 {
            saveHeartbeatsIntervalLabel.text = everyString.localized()
                + " " + "\(viewModel.saveHeartbeatsInterval.value.bound)"
                + " " + "Heartbeat.Interval.Min.string".localized()
        } else {
            saveHeartbeatsIntervalLabel.text = "Heartbeat.Interval.All.string".localized()
        }
        readRSSITitleLabel.text = viewModel.readRSSITitle
        readRSSIIntervalLabel.text = everyString.localized()
            + " " + "\(viewModel.readRSSIInterval.value.bound)"
            + " " + "Heartbeat.Interval.Sec.string".localized()
    }
}

// MARK: - IBActions
extension HeartbeatTableViewController {
    @IBAction func readRSSISwitchValueChanged(_ sender: Any) {
        viewModel.readRSSI.value = readRSSISwitch.isOn
    }

    @IBAction func readRSSIIntervalStepperValueChanged(_ sender: Any) {
        viewModel.readRSSIInterval.value = Int(readRSSIIntervalStepper.value)
    }

    @IBAction func saveHeartbeatsIntervalStepperValueChanged(_ sender: Any) {
        viewModel.saveHeartbeatsInterval.value = Int(saveHeartbeatsIntervalStepper.value)
    }

    @IBAction func saveHeartbeatsSwitchValueChanged(_ sender: Any) {
        viewModel.saveHeartbeats.value = saveHeartbeatsSwitch.isOn
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

            saveHeartbeatsSwitch.bind(viewModel.saveHeartbeats) { (view, isOn) in
                view.isOn = isOn.bound
            }
            let every = everyString
            saveHeartbeatsIntervalLabel.bind(viewModel.saveHeartbeatsInterval) { (label, interval) in
                if interval.bound > 0 {
                    label.text = every.localized()
                                + " " + "\(interval.bound)"
                                + " " + "Heartbeat.Interval.Min.string".localized()
                } else {
                    label.text = "Heartbeat.Interval.All.string".localized()
                }
            }

            readRSSISwitch.bind(viewModel.readRSSI) { (view, isOn) in
                view.isOn = isOn.bound
            }

            readRSSIIntervalLabel.bind(viewModel.readRSSIInterval) { (label, interval) in
                label.text = every.localized()
                            + " " + "\(interval.bound)"
                            + " " + "Heartbeat.Interval.Sec.string".localized()
            }

            saveHeartbeatsIntervalStepper.bind(viewModel.saveHeartbeatsInterval) { (stepper, saveHeartbeatsInterval) in
                stepper.value = Double(saveHeartbeatsInterval.bound)
            }

            readRSSIIntervalStepper.bind(viewModel.readRSSIInterval) { (stepper, readRSSIInterval) in
                stepper.value = Double(readRSSIInterval.bound)
            }

        }
    }

}
