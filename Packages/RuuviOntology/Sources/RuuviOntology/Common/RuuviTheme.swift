#if canImport(UIKit)
import UIKit
#endif

public enum RuuviTheme: String {
    case light, dark, system

#if canImport(UIKit)
    public var uiInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            .unspecified
        }
    }
#endif
}
