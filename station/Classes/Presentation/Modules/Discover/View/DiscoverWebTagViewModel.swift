import UIKit

enum DiscoverWebTagViewModelLocationType {
    case current
    case manual
}

struct DiscoverWebTagViewModel {
    var provider: WeatherProvider
    var locationType: DiscoverWebTagViewModelLocationType
    
    var localizedTitle: String {
        switch locationType {
        case .current:
            return "DiscoverWebTagViewModel.LocationType.current".localized()
        case .manual:
            return "DiscoverWebTagViewModel.LocationType.manual".localized()
        }
    }
}
