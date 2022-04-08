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
    }
}

// MARK: - IBActions
extension HeartbeatTableViewController {
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
            saveHeartbeatsIntervalStepper.bind(viewModel.saveHeartbeatsInterval) { (stepper, saveHeartbeatsInterval) in
                stepper.value = Double(saveHeartbeatsInterval.bound)
            }
        }
    }

}
