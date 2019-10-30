import UIKit
#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
#endif

enum TagActionsEmbedSegue: String {
    case swiftUI = "sdfg"
    case uikit = "sdfdsf"
}

class TagActionsViewController: UIViewController {
    var output: TagActionsViewOutput!
    
    var viewModel: TagActionsViewModel! {
        didSet {
#if canImport(SwiftUI) && canImport(Combine)
            if #available(iOS 13, *) {
                env.viewModel = viewModel
            }
#endif
            uikit?.viewModel = viewModel
        }
    }
    
    @IBOutlet weak var uiKitContainer: UIView!
    @IBOutlet weak var swiftUIContainer: UIView!

#if canImport(SwiftUI) && canImport(Combine)
    @available(iOS 13, *)
    private lazy var env = TagActionsEnvironmentObject()
#endif
    
    private var uikit: TagActionsUIKitViewController?
}

extension TagActionsViewController: TagActionsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - View lifecycle
extension TagActionsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        #if SWIFTUI
        if #available(iOS 13, *) {
            return identifier == TagActionsEmbedSegue.swiftUI.rawValue
        } else {
            return identifier == TagActionsEmbedSegue.uikit.rawValue
        }
        #else
        return identifier == TagActionsEmbedSegue.uikit.rawValue
        #endif
    }
    
    #if SWIFTUI && canImport(SwiftUI) && canImport(Combine)
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        if #available(iOS 13, *) {
            env.viewModel = viewModel
            return UIHostingController(coder: coder, rootView: TagActionsView().environmentObject(env))
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
        case TagActionsEmbedSegue.uikit.rawValue:
            uikit = segue.destination as? TagActionsUIKitViewController
            uikit?.output = output
            uikit?.viewModel = viewModel
        default:
            break
        }
    }
}

// MARK: - Configure Views
extension TagActionsViewController {
    func configureViews() {
        uiKitContainer.isHidden = !shouldPerformSegue(withIdentifier: TagActionsEmbedSegue.uikit.rawValue, sender: nil)
        swiftUIContainer.isHidden = !shouldPerformSegue(withIdentifier: TagActionsEmbedSegue.swiftUI.rawValue, sender: nil)
    }
}

