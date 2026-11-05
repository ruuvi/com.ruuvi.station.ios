#if SWIFT_PACKAGE
    import RuuviCore
#endif
import Foundation
import AVFoundation
import Photos

struct PermissionAccess {
    var photoStatus: () -> PHAuthorizationStatus
    var requestPhoto: (@escaping (PHAuthorizationStatus) -> Void) -> Void
    var cameraStatus: () -> AVAuthorizationStatus
    var requestCamera: (@escaping (Bool) -> Void) -> Void

    static var system: PermissionAccess {
        PermissionAccess(
            photoStatus: { PHPhotoLibrary.authorizationStatus(for: .readWrite) },
            requestPhoto: { PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: $0) },
            cameraStatus: {
                #if targetEnvironment(macCatalyst)
                    return .denied
                #else
                    return AVCaptureDevice.authorizationStatus(for: .video)
                #endif
            },
            requestCamera: { completion in
                #if targetEnvironment(macCatalyst)
                    completion(false)
                #else
                    AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
                #endif
            })
    }
}

public final class RuuviCorePermissionImpl: RuuviCorePermission {
    private let locationManager: RuuviCoreLocation
    private let access: PermissionAccess

    public convenience init(locationManager: RuuviCoreLocation) {
        self.init(locationManager: locationManager, access: .system)
    }

    init(locationManager: RuuviCoreLocation, access: PermissionAccess) {
        self.locationManager = locationManager
        self.access = access
    }

    public var isPhotoLibraryPermissionGranted: Bool {
        let status = access.photoStatus()
        return status == .authorized || status == .limited
    }

    public var photoLibraryAuthorizationStatus: PHAuthorizationStatus {
        access.photoStatus()
    }

    public var isCameraPermissionGranted: Bool {
        access.cameraStatus() == .authorized
    }

    #if targetEnvironment(macCatalyst)
    #else
        public var cameraAuthorizationStatus: AVAuthorizationStatus {
            access.cameraStatus()
        }
    #endif

    @MainActor public var isLocationPermissionGranted: Bool {
        locationManager.isLocationPermissionGranted
    }

    @MainActor public var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.locationAuthorizationStatus
    }

    public func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?) {
        access.requestPhoto { status in
            DispatchQueue.main.async {
                completion?(status == .authorized || status == .limited)
            }
        }
    }

    public func requestCameraPermission(completion: ((Bool) -> Void)?) {
        access.requestCamera { granted in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    @MainActor public func requestLocationPermission(completion: ((Bool) -> Void)?) {
        locationManager.requestLocationPermission { granted in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }
}
