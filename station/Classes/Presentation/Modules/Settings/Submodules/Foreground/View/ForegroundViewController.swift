import UIKit
#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
#endif

class ForegroundViewController: UIViewController {
    var output: ForegroundViewOutput!
    
    var viewModels = [ForegroundViewModel]() {
        didSet {
            table?.viewModels = viewModels
        }
    }
    
    @IBOutlet weak var tableContainer: UIView!
    @IBOutlet weak var listContainer: UIView!
    
    private var table: ForegroundTableViewController?
}

// MARK: - ForegroundViewInput
extension ForegroundViewController: ForegroundViewInput {
    func localize() {
        navigationItem.title = "Foreground.navigationItem.title".localized()
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - View lifecycle
extension ForegroundViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if #available(iOS 13, *) {
            return identifier == ForegroundEmbedSegue.list.rawValue
        } else {
            return identifier == ForegroundEmbedSegue.table.rawValue
        }
    }
    
    #if canImport(SwiftUI) && canImport(Combine)
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        if #available(iOS 13, *) {
            let env = ForegroundEnvironmentObject()
            env.daemons = viewModels
            return UIHostingController(coder: coder, rootView: ForegroundList().environmentObject(env))
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
        case ForegroundEmbedSegue.table.rawValue:
            table = segue.destination as? ForegroundTableViewController
            table?.output = output
            table?.viewModels = viewModels
        default:
            break
        }
    }
}

// MARK: - Configure Views
extension ForegroundViewController {
    func configureViews() {
        tableContainer.isHidden = !shouldPerformSegue(withIdentifier: ForegroundEmbedSegue.table.rawValue, sender: nil)
        listContainer.isHidden = !shouldPerformSegue(withIdentifier: ForegroundEmbedSegue.list.rawValue, sender: nil)
    }
}
