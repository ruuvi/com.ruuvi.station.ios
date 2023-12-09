import Foundation
import Photos
import RuuviCore

public final class RuuviCorePermissionImpl: RuuviCorePermission {
    private let locationManager: RuuviCoreLocation

    public init(locationManager: RuuviCoreLocation) {
        self.locationManager = locationManager
    }

    public var isPhotoLibraryPermissionGranted: Bool {
        PHPhotoLibrary.authorizationStatus() == .authorized
    }

    public var photoLibraryAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus()
    }

    public var isCameraPermissionGranted: Bool {
        #if targetEnvironment(macCatalyst)
            return false
        #else
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        #endif
    }

    #if targetEnvironment(macCatalyst)
    #else
        public var cameraAuthorizationStatus: AVAuthorizationStatus {
            AVCaptureDevice.authorizationStatus(for: .video)
        }
    #endif

    public var isLocationPermissionGranted: Bool {
        locationManager.isLocationPermissionGranted
    }

    public var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.locationAuthorizationStatus
    }

    public func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion?(status == .authorized)
            }
        }
    }

    public func requestCameraPermission(completion: ((Bool) -> Void)?) {
        #if targetEnvironment(macCatalyst)
            completion?(false)
        #else
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion?(granted)
                }
            }
        #endif
    }

    public func requestLocationPermission(completion: ((Bool) -> Void)?) {
        locationManager.requestLocationPermission { granted in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }
}
