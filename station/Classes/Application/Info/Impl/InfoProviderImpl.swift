import UIKit
import Photos
import CoreLocation
import UserNotifications

class InfoProviderImpl: InfoProvider {
    var deviceModel: String {
        return UIDevice.current.readableModel
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return version + "(" + build + ")"
    }

    var appName: String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "unknown|"
    }

    var systemName: String {
        return UIDevice.current.systemName
    }

    var systemVersion: String {
        return UIDevice.current.systemVersion
    }

    var locationPermission: String {
        var result = "Location: "
        switch CLLocationManager.authorizationStatus() {
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
        #if targetEnvironment(macCatalyst)
            result += "<p>MacCatalyst</p>"
        #else
            result += "<p>Device: " + deviceModel + "</p>"
        #endif
        result += "<p>OS: " + systemName + " " + systemVersion + "</p>"
        result += "<p>App: " + appName + " " + appVersion + "</p>"
        result += "<p>" + locationPermission + "</p>"
        result += "<p>" + photoLibraryPermission + "</p>"
        result += "<p>" + cameraPermission + "</p>"

        result += "<p>Notifications: "
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
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
                result += "</p>"
                completion(result)
            }
        }
    }

}
