import RuuviLocalization
import Foundation
import RuuviCore

extension RuuviCoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return RuuviLocalization.CoreError.locationPermissionDenied
        case .locationPermissionNotDetermined:
            return RuuviLocalization.CoreError.locationPermissionNotDetermined
        case .failedToGetCurrentLocation:
            return RuuviLocalization.CoreError.failedToGetCurrentLocation
        }
    }
}
