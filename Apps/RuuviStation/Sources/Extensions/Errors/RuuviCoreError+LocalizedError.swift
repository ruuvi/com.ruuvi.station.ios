import Foundation
import RuuviCore
import RuuviLocalization

extension RuuviCoreError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            RuuviLocalization.CoreError.locationPermissionDenied
        case .locationPermissionNotDetermined:
            RuuviLocalization.CoreError.locationPermissionNotDetermined
        case .failedToGetCurrentLocation:
            RuuviLocalization.CoreError.failedToGetCurrentLocation
        }
    }
}
