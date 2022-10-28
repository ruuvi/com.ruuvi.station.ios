import UIKit

class MenuTableEmbededViewController: UITableViewController, MenuViewInput {
    var output: MenuViewOutput!

    @IBOutlet weak var feedbackCell: UITableViewCell!
    @IBOutlet weak var addRuuviTagCell: UITableViewCell!
    @IBOutlet weak var aboutCell: UITableViewCell!
    @IBOutlet weak var WhatToMeasureCell: UITableViewCell!
    @IBOutlet weak var getMoreSensorsCell: UITableViewCell!
    @IBOutlet weak var buyRuuviGatewayCell: UITableViewCell!
    @IBOutlet weak var settingsCell: UITableViewCell!
    @IBOutlet weak var accountCell: UITableViewCell!
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var addANewSensorLabel: UILabel!
    @IBOutlet weak var appSettingsLabel: UILabel!
    @IBOutlet weak var aboutHelpLabel: UILabel!
    @IBOutlet weak var whatToMeasureLabel: UILabel!
    @IBOutlet weak var getMoreSensorsLabel: UILabel!
    @IBOutlet weak var buyRuuviGatewayLabel: UILabel!
    @IBOutlet weak var accountAuthLabel: UILabel!
}

// MARK: - MenuViewInput
extension MenuTableEmbededViewController {
    func localize() {
        addANewSensorLabel.text = "Menu.Label.AddAnNewSensor.text".localized()
        appSettingsLabel.text = "Menu.Label.AppSettings.text".localized()
        aboutHelpLabel.text = "Menu.Label.AboutHelp.text".localized()
        whatToMeasureLabel.text = "Menu.Label.WhatToMeasure.text".localized()
        getMoreSensorsLabel.text = "Menu.Label.GetMoreSensors.text".localized()
        buyRuuviGatewayLabel.text = "Menu.Label.BuyRuuviGateway.text".localized()
        feedbackLabel.text = "Menu.Label.Feedback.text".localized()
    }
}

// MARK: - View lifecycle
extension MenuTableEmbededViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
    }

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
            ? "Menu.Label.MyRuuviAccount.text".localized()
                : "SignIn.Title.text".localized()
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
            case WhatToMeasureCell:
                output.viewDidSelectWhatToMeasure()
            case getMoreSensorsCell:
                output.viewDidSelectGetMoreSensors()
            case buyRuuviGatewayCell:
                output.viewDidSelectGetRuuviGateway()
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
