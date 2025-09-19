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
    var isLocationPermissionGranted: Bool { get }
    var locationAuthorizationStatus: CLAuthorizationStatus { get }

    @available(*, deprecated, message: "Use async requestPhotoLibraryPermission()")
    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?)
    @available(*, deprecated, message: "Use async requestCameraPermission()")
    func requestCameraPermission(completion: ((Bool) -> Void)?)
    @available(*, deprecated, message: "Use async requestLocationPermission()")
    func requestLocationPermission(completion: ((Bool) -> Void)?)

    // Async versions
    func requestPhotoLibraryPermission() async -> Bool
    func requestCameraPermission() async -> Bool
    func requestLocationPermission() async -> Bool
}
