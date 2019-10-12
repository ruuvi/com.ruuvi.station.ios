import UIKit
#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
#endif

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
    
    #if canImport(SwiftUI) && canImport(Combine)
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        if #available(iOS 13, *) {
            let env = DaemonsEnvironmentObject()
            env.daemons = viewModels
            return UIHostingController(coder: coder, rootView: DaemonsList().environmentObject(env))
        } else {
            return nil
        }
    }
    #else
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        return nil
    }
    #endif
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case DaemonsEmbedSegue.table.rawValue:
            let table = segue.destination as! DaemonsTableViewController
            table.output = output
            table.viewModels = viewModels
        default:
            break
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
