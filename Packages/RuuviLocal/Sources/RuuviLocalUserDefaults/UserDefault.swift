#if SWIFT_PACKAGE
    import RuuviLocal
#endif
import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            if let optional = newValue as? OptionalPreference, optional.isNil {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(newValue, forKey: key)
            }
        }
    }
}

private protocol OptionalPreference {
    var isNil: Bool { get }
}

extension Optional: OptionalPreference {
    fileprivate var isNil: Bool { self == nil }
}
