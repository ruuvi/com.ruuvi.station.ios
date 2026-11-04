import Foundation

public struct RuuviCloudApiHelper {
    public static func jsonStringFromArray(_ array: [String]) -> String? {
        do {
            let jsonData = try JSONEncoder().encode(array)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }

    public static func jsonArrayFromString(_ jsonString: String) -> [String]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }

        do {
            let array = try JSONDecoder().decode([String].self, from: jsonData)
            return array
        } catch {
            return nil
        }
    }
}
