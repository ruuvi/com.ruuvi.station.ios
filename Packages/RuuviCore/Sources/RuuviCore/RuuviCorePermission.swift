import Foundation
import CoreLocation
import AVFoundation
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

    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?)
    func requestCameraPermission(completion: ((Bool) -> Void)?)
    func requestLocationPermission(completion: ((Bool) -> Void)?)
}
