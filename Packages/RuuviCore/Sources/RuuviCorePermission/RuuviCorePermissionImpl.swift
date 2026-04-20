import AVFoundation
import Foundation
import Photos

public final class RuuviCorePermissionImpl: RuuviCorePermission {
    private let locationManager: RuuviCoreLocation
    private let photoAuthorizationStatusProvider: () -> PHAuthorizationStatus
    private let requestPhotoAuthorization: (@escaping (PHAuthorizationStatus) -> Void) -> Void
    #if targetEnvironment(macCatalyst)
    #else
        private let cameraAuthorizationStatusProvider: () -> AVAuthorizationStatus
        private let requestCameraAccess: (@escaping (Bool) -> Void) -> Void
    #endif

    public convenience init(locationManager: RuuviCoreLocation) {
        self.init(
            locationManager: locationManager,
            photoAuthorizationStatusProvider: PHPhotoLibrary.authorizationStatus,
            requestPhotoAuthorization: PHPhotoLibrary.requestAuthorization
        )
    }

    init(
        locationManager: RuuviCoreLocation,
        photoAuthorizationStatusProvider: @escaping () -> PHAuthorizationStatus,
        requestPhotoAuthorization: @escaping (@escaping (PHAuthorizationStatus) -> Void) -> Void,
        cameraAuthorizationStatusProvider: @escaping () -> AVAuthorizationStatus = {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        requestCameraAccess: @escaping (@escaping (Bool) -> Void) -> Void = { completion in
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        }
    ) {
        self.locationManager = locationManager
        self.photoAuthorizationStatusProvider = photoAuthorizationStatusProvider
        self.requestPhotoAuthorization = requestPhotoAuthorization
        #if targetEnvironment(macCatalyst)
        #else
            self.cameraAuthorizationStatusProvider = cameraAuthorizationStatusProvider
            self.requestCameraAccess = requestCameraAccess
        #endif
    }

    public var isPhotoLibraryPermissionGranted: Bool {
        photoAuthorizationStatusProvider() == .authorized
    }

    public var photoLibraryAuthorizationStatus: PHAuthorizationStatus {
        photoAuthorizationStatusProvider()
    }

    public var isCameraPermissionGranted: Bool {
        #if targetEnvironment(macCatalyst)
            return false
        #else
            return cameraAuthorizationStatusProvider() == .authorized
        #endif
    }

    #if targetEnvironment(macCatalyst)
    #else
        public var cameraAuthorizationStatus: AVAuthorizationStatus {
            cameraAuthorizationStatusProvider()
        }
    #endif

    public var isLocationPermissionGranted: Bool {
        locationManager.isLocationPermissionGranted
    }

    public var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.locationAuthorizationStatus
    }

    public func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?) {
        requestPhotoAuthorization { status in
            DispatchQueue.main.async {
                completion?(status == .authorized)
            }
        }
    }

    public func requestCameraPermission(completion: ((Bool) -> Void)?) {
        #if targetEnvironment(macCatalyst)
            completion?(false)
        #else
            requestCameraAccess { granted in
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
