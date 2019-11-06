import UIKit

class TagChartsTransitionManager: NSObject {
    
    var container: UIViewController
    var charts: UIViewController
    var isInteractive: Bool = false
    var presentDirection: UIRectEdge = .bottom
    
    init(container: UIViewController, charts: UIViewController) {
        self.container = container
        self.charts = charts
    }
    
}
