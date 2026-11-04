#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviContext
    import RuuviReactor
    import RuuviLocal
    import RuuviService
    import RuuviPresenters
    import RuuviLocalization
#endif
import Foundation
import UIKit

public extension Bundle {
    static func pod(_ clazz: AnyClass) -> Bundle {
        if let module = NSStringFromClass(clazz).components(separatedBy: ".").first {
            if let bundleURL = Bundle(
                for: clazz
            ).resourceURL?.appendingPathComponent(
                "\(module).bundle"
            ),
                let bundle = Bundle(
                    url: bundleURL
                )
            {
                return bundle
            } else if let bundleURL = Bundle(for: clazz).resourceURL, let bundle = Bundle(url: bundleURL) {
                return bundle
            } else {
                assertionFailure()
                return Bundle.main
            }
        } else {
            assertionFailure()
            return Bundle.main
        }
    }
}

public extension UIStoryboard {
    static func named(_ name: String, for clazz: AnyClass) -> UIStoryboard {
        return UIStoryboard(name: name, bundle: Bundle.pod(clazz))
    }
}
