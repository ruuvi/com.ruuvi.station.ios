import CoreLocation
import Photos
import UIKit
import UserNotifications

class InfoProviderImpl: InfoProvider {
    private let appInfo: [String: Any]
    private let locationStatus: () -> CLAuthorizationStatus
    private let photoStatus: () -> PHAuthorizationStatus
    private let cameraStatus: () -> AVAuthorizationStatus
    private let notificationStatus: (@escaping (UNAuthorizationStatus) -> Void) -> Void

    init(
        appInfo: [String: Any] = Bundle.main.infoDictionary ?? [:],
        locationStatus: @escaping () -> CLAuthorizationStatus = { CLLocationManager().authorizationStatus },
        photoStatus: @escaping () -> PHAuthorizationStatus = { PHPhotoLibrary.authorizationStatus() },
        cameraStatus: @escaping () -> AVAuthorizationStatus = { AVCaptureDevice.authorizationStatus(for: .video) },
        notificationStatus: @escaping (@escaping (UNAuthorizationStatus) -> Void) -> Void = { receive in
            UNUserNotificationCenter.current().getNotificationSettings { receive($0.authorizationStatus) }
        }
    ) {
        self.appInfo = appInfo
        self.locationStatus = locationStatus
        self.photoStatus = photoStatus
        self.cameraStatus = cameraStatus
        self.notificationStatus = notificationStatus
    }

    var deviceModel: String {
        UIDevice.modelName
    }

    var appVersion: String {
        let version = appInfo["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = appInfo["CFBundleVersion"] as? String ?? "unknown"
        return version + "(" + build + ")"
    }

    var appName: String {
        appInfo["CFBundleDisplayName"] as? String ?? "unknown"
    }

    var systemName: String {
        UIDevice.current.systemName
    }

    var systemVersion: String {
        UIDevice.current.systemVersion
    }

    var locationPermission: String {
        var result = "Location: "
        switch locationStatus() {
        case .authorizedAlways:
            result += "always"
        case .authorizedWhenInUse:
            result += "when in use"
        case .denied:
            result += "denied"
        case .notDetermined:
            result += notDetermined
        case .restricted:
            result += "restricted"
        @unknown default:
            result += "unknown"
        }
        return result
    }

    var photoLibraryPermission: String {
        var result = "Photo Library: "
        switch photoStatus() {
        case .authorized:
            result += "authorized"
        case .denied:
            result += "denied"
        case .notDetermined:
            result += notDetermined
        case .restricted:
            result += "restricted"
        case .limited:
            result += "limited"
        @unknown default:
            result += "unknown"
        }
        return result
    }

    var cameraPermission: String {
        var result = "Camera: "
        #if targetEnvironment(macCatalyst)
            result += "unknown"
        #else
            switch cameraStatus() {
            case .authorized:
                result += "authorized"
            case .denied:
                result += "denied"
            case .notDetermined:
                result += notDetermined
            case .restricted:
                result += "restricted"
            @unknown default:
                result += "unknown"
            }
        #endif
        return result
    }

    private let notDetermined = "not determined"

    func summary(completion: @escaping (String) -> Void) {
        var result = ""
        result += "------------------------------------------\n"
        #if targetEnvironment(macCatalyst)
            result += "MacCatalyst"
        #else
            result += "Device: " + deviceModel + "\n"
        #endif
        result += "OS: " + systemName + " " + systemVersion + "\n"
        result += "App: " + appName + " " + appVersion + "\n"
        result += locationPermission + "\n"
        result += photoLibraryPermission + "\n"
        result += cameraPermission + "\n"

        result += "Notifications: "
        notificationStatus { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    result += "authorized"
                case .provisional:
                    result += "provisional"
                case .denied:
                    result += "denied"
                case .notDetermined:
                    result += "notDetermined"
                case .ephemeral:
                    result += "ephemeral"
                @unknown default:
                    result += "unknown"
                }
                result += "\n------------------------------------------\n"
                completion(result)
            }
        }
    }
}
