import Foundation
import Photos
import RuuviCore

class PermissionsManagerImpl: PermissionsManager {
    var locationManager: RuuviCoreLocation!

    var isPhotoLibraryPermissionGranted: Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }

    var photoLibraryAuthorizationStatus: PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }

    var isCameraPermissionGranted: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        #endif
    }

    #if targetEnvironment(macCatalyst)
    #else
    var cameraAuthorizationStatus: AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }
    #endif

    var isLocationPermissionGranted: Bool {
        return locationManager.isLocationPermissionGranted
    }

    var locationAuthorizationStatus: CLAuthorizationStatus {
        return locationManager.locationAuthorizationStatus
    }

    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?) {
        PHPhotoLibrary.requestAuthorization({ (status) in
            DispatchQueue.main.async {
                completion?(status == .authorized)
            }
        })
    }

    func requestCameraPermission(completion: ((Bool) -> Void)?) {
        #if targetEnvironment(macCatalyst)
        completion?(false)
        #else
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
        #endif
    }

    func requestLocationPermission(completion: ((Bool) -> Void)?) {
        locationManager.requestLocationPermission { (granted) in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

}
