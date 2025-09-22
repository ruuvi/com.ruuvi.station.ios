import Foundation
import Photos

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

    // MARK: - Async versions

    public func requestPhotoLibraryPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    public func requestCameraPermission() async -> Bool {
        #if targetEnvironment(macCatalyst)
            return false
        #else
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        #endif
    }

    public func requestLocationPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            locationManager.requestLocationPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
