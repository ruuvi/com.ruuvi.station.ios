#if SWIFT_PACKAGE
    import RuuviCloud
#endif
import CoreFoundation
import Foundation

/// Cloud GET endpoints accept a flat object of strings, numbers and booleans.
/// URLComponents owns percent encoding; JSONEncoder preserves each model's coding keys.
enum RuuviCloudQuery {
    static func items(for model: some Encodable) throws -> [URLQueryItem] {
        let data = try JSONEncoder().encode(model)
        guard let fields = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RuuviCloudApiError.badParameters
        }
        return try fields.keys.sorted().compactMap { key in
            let value: String
            switch fields[key] {
            case let string as String:
                value = string
            case let number as NSNumber:
                value =
                    CFGetTypeID(number) == CFBooleanGetTypeID()
                    ? (number.boolValue ? "true" : "false") : number.stringValue
            case is NSNull:
                return nil
            default:
                throw RuuviCloudApiError.badParameters
            }
            return URLQueryItem(name: key, value: value)
        }
    }
}
