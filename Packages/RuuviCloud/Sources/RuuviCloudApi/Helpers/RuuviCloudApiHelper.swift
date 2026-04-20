import Foundation

public struct RuuviCloudApiHelper {
    public static func jsonStringFromArray(_ array: [String]) -> String? {
        let jsonData = try! JSONEncoder().encode(array)
        return String(decoding: jsonData, as: UTF8.self)
    }

    public static func jsonArrayFromString(_ jsonString: String) -> [String]? {
        let jsonData = Data(jsonString.utf8)
        return try? JSONDecoder().decode([String].self, from: jsonData)
    }
}
