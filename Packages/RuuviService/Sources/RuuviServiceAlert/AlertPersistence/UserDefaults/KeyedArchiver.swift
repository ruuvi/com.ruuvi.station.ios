import Foundation

struct KeyedArchiver {
    static func archive(object: Any) -> Data? {
        if #available(iOS 12.0, *) {
            return try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
        } else {
            return NSKeyedArchiver.archivedData(withRootObject: object)
        }
    }

    static func unarchive<T: Any>(_ data: Data, with type: T.Type) -> T? {
        if #available(iOS 12.0, *) {
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? T
        } else {
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? T
        }
    }
}
