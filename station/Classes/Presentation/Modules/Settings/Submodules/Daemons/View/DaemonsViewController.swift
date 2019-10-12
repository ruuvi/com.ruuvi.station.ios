import UIKit
import SwiftUI

class DaemonsViewController: UIViewController {
    var output: DaemonsViewOutput!
    
    var viewModels = [DaemonsViewModel]()
    
    @IBOutlet weak var tableContainer: UIView!
    @IBOutlet weak var listContainer: UIView!
    
}

// MARK: - DaemonsViewInput
extension DaemonsViewController: DaemonsViewInput {
    func localize() {
        navigationItem.title = "Daemons.navigationItem.title".localized()
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - View lifecycle
extension DaemonsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if #available(iOS 13, *) {
            return identifier == DaemonsEmbedSegue.list.rawValue
        } else {
            return identifier == DaemonsEmbedSegue.table.rawValue
        }
    }
    
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        if #available(iOS 13, *) {
            let env = DaemonsEnvironmentObject()
            env.daemons = viewModels
            return UIHostingController(coder: coder, rootView: DaemonsList().environmentObject(env))
        } else {
            return nil
        }
    }
}

// MARK: - Configure Views
extension DaemonsViewController {
    func configureViews() {
        tableContainer.isHidden = !shouldPerformSegue(withIdentifier: DaemonsEmbedSegue.table.rawValue, sender: nil)
        listContainer.isHidden = !shouldPerformSegue(withIdentifier: DaemonsEmbedSegue.list.rawValue, sender: nil)
    }
}
