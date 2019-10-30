import UIKit

class TagActionsTransitionManager: NSObject {
    
    var height: CGFloat = min(round(min((appScreenRect.width), (appScreenRect.height)) * 0.75), 260)
    var container: UIViewController
    var actions: UIViewController
    var isInteractive: Bool = false
    var presentDirection: UIRectEdge = .bottom
    
    static var appScreenRect: CGRect {
        let appWindowRect = UIApplication.shared.keyWindow?.bounds ?? UIWindow().bounds
        return appWindowRect
    }
    
    init(container: UIViewController, actions: UIViewController) {
        self.container = container
        self.actions = actions
    }
    
}
