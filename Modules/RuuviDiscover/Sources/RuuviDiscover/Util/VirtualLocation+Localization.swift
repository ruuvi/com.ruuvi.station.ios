import Foundation
import RuuviOntology

extension VirtualLocation {
    var title: String {
        switch self {
        case .current:
            return "WebTagLocationSource.current".localized(for: DiscoverPresenter.self)
        case .manual:
            return "WebTagLocationSource.manual".localized(for: DiscoverPresenter.self)
        }
    }
}
