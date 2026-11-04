import AVFoundation
import CoreLocation
import Foundation
import Photos

public protocol RuuviCorePermission {
    var isPhotoLibraryPermissionGranted: Bool { get }
    var photoLibraryAuthorizationStatus: PHAuthorizationStatus { get }

    var isCameraPermissionGranted: Bool { get }
    #if targetEnvironment(macCatalyst)
    #else
        var cameraAuthorizationStatus: AVAuthorizationStatus { get }
    #endif
    @MainActor var isLocationPermissionGranted: Bool { get }
    @MainActor var locationAuthorizationStatus: CLAuthorizationStatus { get }

    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?)
    func requestCameraPermission(completion: ((Bool) -> Void)?)
    @MainActor func requestLocationPermission(completion: ((Bool) -> Void)?)
}
