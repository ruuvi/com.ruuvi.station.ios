import UIKit

class TagChartsTransitionManager: NSObject {

    var container: UIViewController
    var charts: UIViewController
    var isInteractive: Bool = false
    var presentDirection: UIRectEdge = .bottom

    static var appScreenRect: CGRect {
       let appWindowRect = UIApplication.shared.keyWindow?.bounds ?? UIWindow().bounds
       return appWindowRect
    }

    init(container: UIViewController, charts: UIViewController) {
        self.container = container
        self.charts = charts
    }

}
