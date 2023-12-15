import RuuviLocalization
import UIKit

class HeartbeatTableViewController: UITableViewController {
    var output: HeartbeatViewOutput!

    var viewModel = HeartbeatViewModel() {
        didSet {
            bindViewModel()
        }
    }

    @IBOutlet var bgScanningTitleLabel: UILabel!
    @IBOutlet var bgScanningSwitch: RuuviUISwitch!
    @IBOutlet var bgScanningIntervalTitleLabel: UILabel!
    @IBOutlet var bgScanningIntervalValueLabel: UILabel!
    @IBOutlet var bgScanningIntervalStepper: UIStepper!
}

// MARK: - HeartbeatViewInput

extension HeartbeatTableViewController: HeartbeatViewInput {
    func localize() {
        bgScanningTitleLabel.text = viewModel.bgScanningTitle
        bgScanningIntervalTitleLabel.text = viewModel.bgScanningIntervalTitle
        if viewModel.bgScanningInterval.value.bound > 0 {
            bgScanningIntervalValueLabel.text = RuuviLocalization.Heartbeat.Interval.Every.string
                + " " + "\(viewModel.bgScanningInterval.value.bound)"
                + " " + RuuviLocalization.Heartbeat.Interval.Min.string
        } else {
            bgScanningIntervalValueLabel.text = RuuviLocalization.Heartbeat.Interval.All.string
        }
    }

    func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
        bgScanningTitleLabel.textColor = RuuviColor.menuTextColor.color
        bgScanningIntervalTitleLabel.textColor = RuuviColor.menuTextColor.color
        bgScanningIntervalValueLabel.textColor = RuuviColor.textColor.color
    }
}

// MARK: - IBActions

extension HeartbeatTableViewController {
    @IBAction func bgScanningIntervalStepperValueChanged(_: Any) {
        viewModel.bgScanningInterval.value = Int(bgScanningIntervalStepper.value)
    }

    @IBAction func bgScanningSwitchValueChanged(_: Any) {
        viewModel.bgScanningState.value = bgScanningSwitch.isOn
    }
}

// MARK: - View lifecycle

extension HeartbeatTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        updateUIComponent()
        localize()
        styleViews()
    }

    private func styleViews() {
        bgScanningIntervalValueLabel.textColor = RuuviColor.textColor.color
    }
}

// MARK: - UI TABLE VIEW

extension HeartbeatTableViewController {
    override func tableView(_: UITableView, estimatedHeightForFooterInSection _: Int) -> CGFloat {
        100
    }

    override func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        let footerView = UIView()
        let footerLabel = UILabel()
        footerLabel.textColor = RuuviColor.textColor.color
        footerLabel.font = UIFont.Muli(.regular, size: 13)
        footerLabel.numberOfLines = 0
        footerLabel.text = RuuviLocalization.Settings.BackgroundScanning.Footer.message
        footerView.addSubview(footerLabel)
        footerLabel.fillSuperview(padding: .init(top: 8, left: 20, bottom: 8, right: 20))
        return footerView
    }
}

// MARK: - Private

extension HeartbeatTableViewController {
    private func updateUIComponent() {
        tableView.sectionFooterHeight = UITableView.automaticDimension
        bgScanningIntervalStepper.layer.cornerRadius = 8
    }

    private func bindViewModel() {
        if isViewLoaded {
            bgScanningSwitch.bind(viewModel.bgScanningState) { view, isOn in
                view.isOn = isOn.bound
            }
            bgScanningIntervalValueLabel.bind(viewModel.bgScanningInterval) { label, interval in
                if interval.bound > 0 {
                    label.text = RuuviLocalization.Heartbeat.Interval.Every.string
                        + " " + "\(interval.bound)"
                        + " " + RuuviLocalization.Heartbeat.Interval.Min.string
                } else {
                    label.text = RuuviLocalization.Heartbeat.Interval.All.string
                }
            }
            bgScanningIntervalStepper.bind(viewModel.bgScanningInterval) { stepper, interval in
                stepper.value = Double(interval.bound)
            }
        }
    }
}
