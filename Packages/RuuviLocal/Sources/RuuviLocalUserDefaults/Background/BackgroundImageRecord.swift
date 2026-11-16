import Foundation
import RuuviOntology

/// One preferences value publishes an immutable image file together with its sync metadata.
struct BackgroundImageRecord {
    static let prefix = "BackgroundPersistenceUserDefaults.imageRecord."
    var file: String?
    var selectedAt: Date?
    var cachedURL: URL?
    var forced = false
    var retiredThrough: Date?

    init(for identifier: Identifier) {
        let defaults = UserDefaults.standard
        if let record = defaults.dictionary(forKey: Self.prefix + identifier.value) {
            file = record["file"] as? String
            selectedAt = record["selectedAt"] as? Date
            cachedURL = (record["cachedURL"] as? String).flatMap(URL.init(string:))
            forced = record["forced"] as? Bool ?? false
            retiredThrough = record["retiredThrough"] as? Date
        } else {
            // Existing installations continue to use their original files until the next write.
            file = identifier.value
            selectedAt = defaults.object(
                forKey: "BackgroundPersistenceUserDefaults.customBackgroundDate." + identifier.value
            ) as? Date
            cachedURL = defaults.url(forKey: "SensorServiceImpl.backgroundUrlPrefix" + identifier.value)
            forced = defaults.bool(forKey: "BackgroundPersistenceUserDefaults.forcedUpload." + identifier.value)
        }
    }

    func save(for identifier: Identifier) {
        var record: [String: Any] = ["forced": forced]
        record["file"] = file
        record["selectedAt"] = selectedAt
        record["cachedURL"] = cachedURL?.absoluteString
        record["retiredThrough"] = retiredThrough
        UserDefaults.standard.set(record, forKey: Self.prefix + identifier.value)
    }
}
