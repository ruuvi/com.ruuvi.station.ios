import Foundation

enum WebTagLocationSource {
    case current
    case manual

    var title: String {
        switch self {
        case .current:
            return "WebTagLocationSource.current".localized()
        case .manual:
            return "WebTagLocationSource.manual".localized()
        }
    }
}
