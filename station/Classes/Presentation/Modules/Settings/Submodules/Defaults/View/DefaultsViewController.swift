import UIKit
import RuuviLocalization
#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
#endif

class DefaultsViewController: UIViewController {
    var output: DefaultsViewOutput!

    var viewModels = [DefaultsViewModel]() {
        didSet {
#if canImport(SwiftUI) && canImport(Combine)
            if #available(iOS 13, *) {
                env.viewModels = viewModels
            }
#endif
            table?.viewModels = viewModels
        }
    }

    @IBOutlet weak var tableContainer: UIView!
    @IBOutlet weak var listContainer: UIView!

#if canImport(SwiftUI) && canImport(Combine)
    @available(iOS 13, *)
    private lazy var env = DefaultsEnvironmentObject()
#endif

    private var table: DefaultsTableViewController?
}

extension DefaultsViewController: DefaultsViewInput {
    func showEndpointChangeConfirmationDialog(useDevServer: Bool?) {
        let message = RuuviLocalization.Defaults.DevServer.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancelActionTitle = RuuviLocalization.cancel
        alert.addAction(UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil))
        let signOutTitle = RuuviLocalization.Menu.SignOut.text
        alert.addAction(UIAlertAction(title: signOutTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidTriggerUseDevServer(useDevServer: useDevServer)
        }))
        present(alert, animated: true)
    }

    func localize() {
        navigationItem.title = RuuviLocalization.Defaults.NavigationItem.title
    }
}

// MARK: - View lifecycle
extension DefaultsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        #if SWIFTUI
        if #available(iOS 13, *) {
            return identifier == DefaultsEmbedSegue.list.rawValue
        } else {
            return identifier == DefaultsEmbedSegue.table.rawValue
        }
        #else
        return identifier == DefaultsEmbedSegue.table.rawValue
        #endif
    }

    #if SWIFTUI && canImport(SwiftUI) && canImport(Combine)
    @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
        if #available(iOS 13, *) {
            env.viewModels = viewModels
            return UIHostingController(coder: coder, rootView: DefaultsList().environmentObject(env))
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
        case DefaultsEmbedSegue.table.rawValue:
            table = segue.destination as? DefaultsTableViewController
            table?.output = output
            table?.viewModels = viewModels
        default:
            break
        }
    }
}

// MARK: - Configure Views
extension DefaultsViewController {
    func configureViews() {
        tableContainer.isHidden = !shouldPerformSegue(withIdentifier: DefaultsEmbedSegue.table.rawValue, sender: nil)
        listContainer.isHidden = !shouldPerformSegue(withIdentifier: DefaultsEmbedSegue.list.rawValue, sender: nil)
    }
}
