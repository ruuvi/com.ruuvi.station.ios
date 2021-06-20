import Foundation
import RuuviVirtual

extension VirtualLocation {
    var title: String {
        switch self {
        case .current:
            return "WebTagLocationSource.current".localized()
        case .manual:
            return "WebTagLocationSource.manual".localized()
        }
    }
}
