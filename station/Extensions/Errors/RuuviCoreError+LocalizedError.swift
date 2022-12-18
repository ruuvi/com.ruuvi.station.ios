import Foundation
import RuuviCore

extension RuuviCoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "CoreError.locationPermissionDenied".localized()
        case .locationPermissionNotDetermined:
            return "CoreError.locationPermissionNotDetermined".localized()
        case .failedToGetCurrentLocation:
            return "CoreError.failedToGetCurrentLocation".localized()
        }
    }
}
