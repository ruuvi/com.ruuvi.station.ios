import UIKit

/// Keeps native alert presentation while allowing action contracts to be exercised independently of UIKit gestures.
@MainActor struct AlertActionFactory {
    typealias Handler = (UIAlertAction) -> Void
    var create: (String?, UIAlertAction.Style, Handler?) -> UIAlertAction = {
        UIAlertAction(title: $0, style: $1, handler: $2)
    }
    func callAsFunction(title: String?, style: UIAlertAction.Style, handler: Handler? = nil) -> UIAlertAction {
        create(title, style, handler)
    }
}
