import RuuviLocalization
import UIKit

class MenuTableEmbededViewController: UITableViewController, MenuViewInput {
    var output: MenuViewOutput!

    @IBOutlet var feedbackCell: UITableViewCell!
    @IBOutlet var addRuuviTagCell: UITableViewCell!
    @IBOutlet var aboutCell: UITableViewCell!
    @IBOutlet var whatToMeasureCell: UITableViewCell!
    @IBOutlet var getMoreSensorsCell: UITableViewCell!
    @IBOutlet var settingsCell: UITableViewCell!
    @IBOutlet var accountCell: UITableViewCell!
    @IBOutlet var feedbackLabel: UILabel!
    @IBOutlet var addANewSensorLabel: UILabel!
    @IBOutlet var appSettingsLabel: UILabel!
    @IBOutlet var aboutHelpLabel: UILabel!
    @IBOutlet var whatToMeasureLabel: UILabel!
    @IBOutlet var getMoreSensorsLabel: UILabel!
    @IBOutlet var accountAuthLabel: UILabel!
}

// MARK: - MenuViewInput

extension MenuTableEmbededViewController {
    func localize() {
        addANewSensorLabel.text = RuuviLocalization.Menu.Label.AddAnNewSensor.text
        appSettingsLabel.text = RuuviLocalization.Menu.Label.AppSettings.text
        aboutHelpLabel.text = RuuviLocalization.Menu.Label.AboutHelp.text
        whatToMeasureLabel.text = RuuviLocalization.Menu.Label.WhatToMeasure.text
        getMoreSensorsLabel.text = RuuviLocalization.Menu.Label.GetMoreSensors.text
        feedbackLabel.text = RuuviLocalization.Menu.Label.Feedback.text
    }
}

// MARK: - View lifecycle

extension MenuTableEmbededViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

// MARK: - UITableViewDelegate

extension MenuTableEmbededViewController {
    override func tableView(
        _: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt _: IndexPath
    ) {
        if cell == accountCell {
            accountAuthLabel.text = output.userIsAuthorized
                ? RuuviLocalization.Menu.Label.MyRuuviAccount.text
                : RuuviLocalization.SignIn.Title.text
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case addRuuviTagCell:
                output.viewDidSelectAddRuuviTag()
            case aboutCell:
                output.viewDidSelectAbout()
            case whatToMeasureCell:
                output.viewDidSelectWhatToMeasure()
            case getMoreSensorsCell:
                output.viewDidSelectGetMoreSensors()
            case settingsCell:
                output.viewDidSelectSettings()
            case feedbackCell:
                output.viewDidSelectFeedback()
            case accountCell:
                output.viewDidSelectAccountCell()
            default:
                break
            }
        }
    }
}
