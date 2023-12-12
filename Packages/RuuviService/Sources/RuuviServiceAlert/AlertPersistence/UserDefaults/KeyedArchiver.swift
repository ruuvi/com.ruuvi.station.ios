import Foundation

enum KeyedArchiver {
    static func archive(object: Any) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
    }

    static func unarchive<T: Any>(_ data: Data, with _: T.Type) -> T? {
        let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver?.requiresSecureCoding = false
        return unarchiver?.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? T
    }
}
