import CoreLocation
import Photos
import UIKit
import UserNotifications

class InfoProviderImpl: InfoProvider {
    var deviceModel: String {
        UIDevice.modelName
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return version + "(" + build + ")"
    }

    var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "unknown|"
    }

    var systemName: String {
        UIDevice.current.systemName
    }

    var systemVersion: String {
        UIDevice.current.systemVersion
    }

    var locationPermission: String {
        var result = "Location: "
        switch CLLocationManager().authorizationStatus {
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
        switch PHPhotoLibrary.authorizationStatus() {
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
            switch AVCaptureDevice.authorizationStatus(for: .video) {
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
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
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
