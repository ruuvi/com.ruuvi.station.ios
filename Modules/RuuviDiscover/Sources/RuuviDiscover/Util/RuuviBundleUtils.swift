import Foundation
import UIKit

public extension Bundle {
    static func pod(_ clazz: AnyClass) -> Bundle {
        if let module = NSStringFromClass(clazz).components(separatedBy: ".").first {
            if let bundleURL = Bundle(
                for: clazz
            ).resourceURL?.appendingPathComponent(
                "\(module).bundle"
            ), let bundle = Bundle(
                url: bundleURL
            ) {
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
        let bundle: Bundle
        #if SWIFT_PACKAGE
            bundle = Bundle.module
        #else
            bundle = Bundle.pod(clazz)
        #endif
        return UIStoryboard(name: name, bundle: bundle)
    }
}
