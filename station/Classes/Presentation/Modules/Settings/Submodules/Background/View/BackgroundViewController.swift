import UIKit
#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
#endif

class BackgroundViewController: UIViewController {
    var output: BackgroundViewOutput!
    
    var viewModels = [BackgroundViewModel]() {
        didSet {
            if #available(iOS 13, *) {
                env.viewModels = viewModels
            }
        }
    }
    
    @IBOutlet weak var tableContainer: UIView!
    @IBOutlet weak var listContainer: UIView!

#if canImport(SwiftUI) && canImport(Combine)
    @available(iOS 13, *)
    private lazy var env = BackgroundEnvironmentObject()
#endif
    
}

extension BackgroundViewController: BackgroundViewInput {
    func localize() {
        navigationItem.title = "Background.navigationItem.title".localized()
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - View lifecycle
extension BackgroundViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if #available(iOS 13, *) {
            return identifier == BackgroundEmbedSegue.list.rawValue
        } else {
            return identifier == BackgroundEmbedSegue.table.rawValue
        }
    }
    
    #if canImport(SwiftUI) && canImport(Combine)
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        if #available(iOS 13, *) {
            env.viewModels = viewModels
            return UIHostingController(coder: coder, rootView: BackgroundList().environmentObject(env))
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
        case BackgroundEmbedSegue.table.rawValue:
            let table = segue.destination as! BackgroundTableViewController
            table.output = output
            table.viewModels = viewModels
        default:
            break
        }
    }
}

// MARK: - Configure Views
extension BackgroundViewController {
    func configureViews() {
        tableContainer.isHidden = !shouldPerformSegue(withIdentifier: BackgroundEmbedSegue.table.rawValue, sender: nil)
        listContainer.isHidden = !shouldPerformSegue(withIdentifier: BackgroundEmbedSegue.list.rawValue, sender: nil)
    }
}
