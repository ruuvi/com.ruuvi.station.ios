import Foundation
import UIKit

extension Bundle {
    public static func pod(_ clazz: AnyClass) -> Bundle {
        if let module = NSStringFromClass(clazz).components(separatedBy: ".").first,
           let bundleURL = Bundle(for: clazz).resourceURL?.appendingPathComponent("\(module).bundle"),
           let bundle = Bundle(url: bundleURL) {
            return bundle
        } else {
            assertionFailure()
            return Bundle.main
        }
    }
}

extension UIImage {
    public static func named(_ name: String, for clazz: AnyClass) -> UIImage? {
        #if SWIFT_PACKAGE
        return UIImage(named: name, in: Bundle.module, compatibleWith: nil)
        #else
        return UIImage(named: name, in: Bundle.pod(clazz), compatibleWith: nil)
        #endif
    }
}

extension String {
    public func localized(for clazz: AnyClass) -> String {
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.pod(clazz)
        #endif
        if let module = NSStringFromClass(clazz).components(separatedBy: ".").first {
            return bundle.localizedString(forKey: self, value: nil, table: module)
        } else {
            assertionFailure()
            return ""
        }
    }
}

extension UIStoryboard {
    public static func named(_ name: String, for clazz: AnyClass) -> UIStoryboard {
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.pod(clazz)
        #endif
        return UIStoryboard(name: name, bundle: bundle)
    }
}

extension UINib {
    public static func nibName(_ nibName: String, for clazz: AnyClass) -> UINib {
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.pod(clazz)
        #endif
        return UINib(nibName: nibName, bundle: bundle)
    }
}
