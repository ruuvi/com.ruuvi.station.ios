import RuuviLocalization
import UIKit
#if canImport(SwiftUI) && canImport(Combine)
    import SwiftUI
#endif

class HeartbeatViewController: UIViewController {
    var output: HeartbeatViewOutput!

    var viewModel = HeartbeatViewModel() {
        didSet {
            #if canImport(SwiftUI) && canImport(Combine)
                if #available(iOS 13, *) {
                    env.viewModel = viewModel
                }
            #endif
            table?.viewModel = viewModel
        }
    }

    @IBOutlet var tableContainer: UIView!
    @IBOutlet var listContainer: UIView!

    #if canImport(SwiftUI) && canImport(Combine)
        @available(iOS 13, *)
        private lazy var env = HeartbeatEnvironmentObject()
    #endif

    private var table: HeartbeatTableViewController?
}

extension HeartbeatViewController: HeartbeatViewInput {
    func localize() {
        navigationItem.title = RuuviLocalization.Settings.BackgroundScanning.title
    }
}

// MARK: - View lifecycle

extension HeartbeatViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        localize()
        styleViews()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender _: Any?) -> Bool {
        #if SWIFTUI
            if #available(iOS 13, *) {
                return identifier == HeartbeatEmbedSegue.list.rawValue
            } else {
                return identifier == HeartbeatEmbedSegue.table.rawValue
            }
        #else
            return identifier == HeartbeatEmbedSegue.table.rawValue
        #endif
    }

    #if SWIFTUI && canImport(SwiftUI) && canImport(Combine)
        @IBSegueAction func addSwiftUIView(_ coder: NSCoder) -> UIViewController? {
            if #available(iOS 13, *) {
                env.viewModel = viewModel
                return UIHostingController(coder: coder, rootView: HeartbeatList().environmentObject(env))
            } else {
                return nil
            }
        }
    #else
        @IBSegueAction func addSwiftUIView(_: NSCoder) -> UIViewController? {
            nil
        }
    #endif

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        switch segue.identifier {
        case HeartbeatEmbedSegue.table.rawValue:
            table = segue.destination as? HeartbeatTableViewController
            table?.output = output
            table?.viewModel = viewModel
        default:
            break
        }
    }
}

// MARK: - Configure Views

extension HeartbeatViewController {
    func configureViews() {
        tableContainer.isHidden = !shouldPerformSegue(withIdentifier: HeartbeatEmbedSegue.table.rawValue, sender: nil)
        listContainer.isHidden = !shouldPerformSegue(withIdentifier: HeartbeatEmbedSegue.list.rawValue, sender: nil)
    }
}
