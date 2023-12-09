import RuuviLocalization
import UIKit

class MenuTableEmbededViewController: UITableViewController, MenuViewInput {
    var output: MenuViewOutput!

    @IBOutlet weak var feedbackCell: UITableViewCell!
    @IBOutlet weak var addRuuviTagCell: UITableViewCell!
    @IBOutlet weak var aboutCell: UITableViewCell!
    @IBOutlet weak var whatToMeasureCell: UITableViewCell!
    @IBOutlet weak var getMoreSensorsCell: UITableViewCell!
    @IBOutlet weak var settingsCell: UITableViewCell!
    @IBOutlet weak var accountCell: UITableViewCell!
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var addANewSensorLabel: UILabel!
    @IBOutlet weak var appSettingsLabel: UILabel!
    @IBOutlet weak var aboutHelpLabel: UILabel!
    @IBOutlet weak var whatToMeasureLabel: UILabel!
    @IBOutlet weak var getMoreSensorsLabel: UILabel!
    @IBOutlet weak var accountAuthLabel: UILabel!
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
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

// MARK: - UITableViewDelegate
extension MenuTableEmbededViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView,
                            willDisplay cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
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
