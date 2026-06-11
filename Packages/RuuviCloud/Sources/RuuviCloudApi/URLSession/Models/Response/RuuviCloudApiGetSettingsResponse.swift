import Foundation
import RuuviOntology

public struct RuuviCloudApiGetSettingsResponse: Decodable {
    public let settings: RuuviCloudApiSettings?
}

public struct RuuviCloudApiSettings: Decodable, RuuviCloudSettings {
    private static let lastUpdatedSuffix = "_lastUpdated"

    public let userSettings: [RuuviUserSetting]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var values = [RuuviCloudApiSetting: String]()
        var lastUpdatedDates = [RuuviCloudApiSetting: Date]()

        for key in container.allKeys {
            let keyString = key.stringValue
            if keyString.hasSuffix(Self.lastUpdatedSuffix) {
                let settingKey = String(keyString.dropLast(Self.lastUpdatedSuffix.count))
                guard let setting = RuuviCloudApiSetting(rawValue: settingKey),
                      let date = Self.date(from: container, forKey: key)
                else { continue }
                lastUpdatedDates[setting] = date
            } else {
                guard let setting = RuuviCloudApiSetting(rawValue: keyString),
                      let value = Self.stringValue(from: container, forKey: key)
                else { continue }
                values[setting] = value
            }
        }

        userSettings = RuuviCloudApiSetting.userSettingKeys.compactMap { setting in
            guard let value = values[setting] else {
                return nil
            }
            return RuuviUserSettingStruct(
                key: setting.rawValue,
                value: value,
                lastUpdated: lastUpdatedDates[setting]
            )
        }
    }

    private static func stringValue(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        forKey key: DynamicCodingKey
    ) -> String? {
        if (try? container.decodeNil(forKey: key)) == true {
            return nil
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return value.rounded() == value ? String(Int(value)) : String(value)
        }
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value.chartBoolSettingString
        }
        return nil
    }

    private static func date(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        forKey key: DynamicCodingKey
    ) -> Date? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: value)
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(value))
        }
        if let value = try? container.decode(String.self, forKey: key),
           let timestamp = Double(value) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
