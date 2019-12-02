import Foundation
import Photos

class PermissionsManagerImpl: PermissionsManager {

    var locationManager: LocationManager!

    var isPhotoLibraryPermissionGranted: Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }

    var isCameraPermissionGranted: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    var isLocationPermissionGranted: Bool {
        return locationManager.isLocationPermissionGranted
    }

    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?) {
        PHPhotoLibrary.requestAuthorization({ (status) in
            DispatchQueue.main.async {
                completion?(status == .authorized)
            }
        })
    }

    func requestCameraPermission(completion: ((Bool) -> Void)?) {
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    func requestLocationPermission(completion: ((Bool) -> Void)?) {
        locationManager.requestLocationPermission { (granted) in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

}
