import Foundation
import Photos

class PermissionsManagerImpl: PermissionsManager {
    
    var isPhotoLibraryPermissionGranted: Bool {
        get {
            return PHPhotoLibrary.authorizationStatus() == .authorized
        }
    }
    
    var isCameraPermissionGranted: Bool {
        get {
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
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
    
}
