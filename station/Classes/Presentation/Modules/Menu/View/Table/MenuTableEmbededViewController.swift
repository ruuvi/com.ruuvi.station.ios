import UIKit

class MenuTableEmbededViewController: UITableViewController {
    var output: MenuViewOutput!
    
    @IBOutlet weak var addRuuviTagCell: UITableViewCell!
    @IBOutlet weak var aboutCell: UITableViewCell!
    @IBOutlet weak var getMoreSensorsCell: UITableViewCell!
    @IBOutlet weak var settingsCell: UITableViewCell!
}

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
