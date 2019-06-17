import UIKit

class MenuTableViewController: UIViewController {
    var output: MenuViewOutput!
}

extension MenuTableViewController: MenuViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

extension MenuTableViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "EmbedMenuTableEmbededViewControllerSegueIdentifier" {
            let embeded = segue.destination as! MenuTableEmbededViewController
            embeded.output = output
        }
    }
}
