import Foundation
import CoreLocation
import Photos
import AVFoundation

protocol PermissionsManager {
    var isPhotoLibraryPermissionGranted: Bool { get }
    var photoLibraryAuthorizationStatus: PHAuthorizationStatus { get }

    var isCameraPermissionGranted: Bool { get }
    var cameraAuthorizationStatus: AVAuthorizationStatus { get }
    var isLocationPermissionGranted: Bool { get }
    var locationAuthorizationStatus: CLAuthorizationStatus { get }

    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?)
    func requestCameraPermission(completion: ((Bool) -> Void)?)
    func requestLocationPermission(completion: ((Bool) -> Void)?)
}
