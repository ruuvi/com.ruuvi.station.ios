import Foundation

public enum RuuviCoreError: Error {
    case locationPermissionDenied
    case locationPermissionNotDetermined
    case failedToGetCurrentLocation
}
