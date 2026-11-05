import Foundation

final class WidgetResourceBundleToken {}

enum WidgetResources {
    static let bundle = Bundle(for: WidgetResourceBundleToken.self)
}
