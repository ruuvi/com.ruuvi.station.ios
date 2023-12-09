import UIKit

public enum RuuviTheme: String {
    case light, dark, system

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
}
