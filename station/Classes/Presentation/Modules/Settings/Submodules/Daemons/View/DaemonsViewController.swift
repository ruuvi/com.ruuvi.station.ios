import UIKit
import SwiftUI

class DaemonsViewController: UIViewController {
    var output: DaemonsViewOutput!
    
    var viewModels = [DaemonsViewModel]()
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
