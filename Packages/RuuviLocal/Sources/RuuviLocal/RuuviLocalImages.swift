import Future
import RuuviOntology
import UIKit

public extension Notification.Name {
    static let BackgroundPersistenceDidChangeBackground
        = Notification.Name("BackgroundPersistenceDidChangeBackground")
    static let BackgroundPersistenceDidUpdateBackgroundUploadProgress
        = Notification.Name("BackgroundPersistenceDidUpdateBackgroundUploadProgress")
}

public enum BPDidChangeBackgroundKey: String {
    case luid // LocalIdenfitier
    case macId
}

public enum BPDidUpdateBackgroundUploadProgressKey: String {
    case luid // LocalIdenfitier
    case macId
    case progress
}

public protocol RuuviLocalImages {
    func getOrGenerateBackground(
        for identifier: Identifier,
        ruuviDeviceType: RuuviDeviceType
    ) -> UIImage?
    func getBackground(for identifier: Identifier) -> UIImage?
    func setBackground(_ id: Int, for identifier: Identifier)
    func setNextDefaultBackground(for identifier: Identifier) -> UIImage?
    func hasCustomBackground(for identifier: Identifier) -> Bool
    func backgroundUploadData(for identifier: Identifier) -> Future<Data, RuuviLocalError>
    func setUserSelectedBackground(
        image: UIImage, compressionQuality: CGFloat, selectedAt: Date, for identifier: Identifier
    ) -> Future<URL, RuuviLocalError>
    /// Publishes the image and its cloud URL together, only while the download is still current.
    func setDownloadedBackground(
        image: UIImage, from url: URL, for identifier: Identifier, canPublish: @escaping () -> Bool
    ) -> Future<URL, RuuviLocalError>
    func backgroundUploadRetiredThrough(for identifier: Identifier) -> Date?
    func acknowledgeBackgroundUpload(_ url: URL, selectedAt: Date, for identifier: Identifier)
    func getCustomBackground(for identifier: Identifier) -> UIImage?
    func setCustomBackground(
        image: UIImage,
        compressionQuality: CGFloat,
        for identifier: Identifier
    ) -> Future<
        URL,
        RuuviLocalError
    >
    func deleteCustomBackground(for uuid: Identifier)
    func customBackgroundLastUpdated(for identifier: Identifier) -> Date?
    func setCustomBackgroundLastUpdated(_ date: Date?, for identifier: Identifier)

    /// Local saves block reconciliation; an older cloud-cache write must not block a newer download.
    func isBackgroundWritePending(for identifier: Identifier) -> Bool
    func cachedPictureURL(for identifier: Identifier) -> URL?
    func setCachedPictureURL(_ url: URL?, for identifier: Identifier)
    func isBackgroundUploadForced(for identifier: Identifier) -> Bool
    func setBackgroundUploadForced(_ forced: Bool, for identifier: Identifier)

    func backgroundUploadProgress(for identifier: Identifier) -> Double?
    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier)
    func deleteBackgroundUploadProgress(for identifier: Identifier)

    func isPictureCached(for cloudSensor: CloudSensor) -> Bool
    func setPictureIsCached(for cloudSensor: CloudSensor)
    func setPictureRemovedFromCache(for ruuviTag: RuuviTagSensor)
}

public extension RuuviLocalImages {
    func matchesCachedPicture(_ url: URL?, for identifier: Identifier) -> Bool {
        guard let url, let cached = cachedPictureURL(for: identifier) else { return false }
        if !url.pathExtension.isEmpty, !cached.pathExtension.isEmpty {
            return url.lastPathComponent == cached.lastPathComponent
        }
        return url == cached
    }

    /// Ownership acquisition deliberately keeps whichever local custom image is displayed.
    func customBackground(for sensor: RuuviTagSensor) -> (image: UIImage, identifier: Identifier)? {
        guard let identifier = customBackgroundIdentifier(for: sensor),
              let image = getCustomBackground(for: identifier) else { return nil }
        return (image, identifier)
    }

    func customBackgroundIdentifier(for sensor: RuuviTagSensor) -> Identifier? {
        let identifiers: [Identifier?] = [sensor.macId, sensor.luid]
        return identifiers.compactMap { $0 }.sorted {
            (customBackgroundLastUpdated(for: $0) ?? .distantPast)
                > (customBackgroundLastUpdated(for: $1) ?? .distantPast)
        }.first { hasCustomBackground(for: $0) }
    }

    /// Downloaded cache files have no selection date and must never become upload candidates.
    func userSelectedBackground(for sensor: RuuviTagSensor) -> (image: UIImage, lastUpdated: Date)? {
        guard let background = customBackground(for: sensor),
              let date = customBackgroundLastUpdated(for: background.identifier) else { return nil }
        return (background.image, date)
    }
}
