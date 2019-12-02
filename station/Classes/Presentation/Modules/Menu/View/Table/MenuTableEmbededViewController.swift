import UIKit

class MenuTableEmbededViewController: UITableViewController, MenuViewInput {
    var output: MenuViewOutput!

    @IBOutlet weak var addRuuviTagCell: UITableViewCell!
    @IBOutlet weak var aboutCell: UITableViewCell!
    @IBOutlet weak var getMoreSensorsCell: UITableViewCell!
    @IBOutlet weak var settingsCell: UITableViewCell!
    @IBOutlet weak var addANewSensorLabel: UILabel!
    @IBOutlet weak var appSettingsLabel: UILabel!
    @IBOutlet weak var aboutHelpLabel: UILabel!
    @IBOutlet weak var getMoreSensorsLabel: UILabel!
}

// MARK: - MenuViewInput
extension MenuTableEmbededViewController {
    func localize() {
        addANewSensorLabel.text = "Menu.Label.AddAnNewSensor.text".localized()
        appSettingsLabel.text = "Menu.Label.AppSettings.text".localized()
        aboutHelpLabel.text = "Menu.Label.AboutHelp.text".localized()
        getMoreSensorsLabel.text = "Menu.Label.GetMoreSensors.text".localized()
    }

    func apply(theme: Theme) {

    }
}

// MARK: - View lifecycle
extension MenuTableEmbededViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
    }
}

// MARK: - UITableViewDelegate
extension MenuTableEmbededViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case addRuuviTagCell:
                output.viewDidSelectAddRuuviTag()
            case aboutCell:
                output.viewDidSelectAbout()
            case getMoreSensorsCell:
                output.viewDidSelectGetMoreSensors()
            case settingsCell:
                output.viewDidSelectSettings()
            default:
                break
            }
        }
    }
}
