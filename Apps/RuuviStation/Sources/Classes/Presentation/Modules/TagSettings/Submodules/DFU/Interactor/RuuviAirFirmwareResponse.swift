import Foundation
import RuuviDFU

struct RuuviAirFirmwareResponse: Codable {
    let result: String
    let data: RuuviAirFirmwareData
}

struct RuuviAirFirmwareData: Codable {
    let latest: RuuviAirFirmwareDataModel?
    let alpha: RuuviAirFirmwareDataModel?
    let beta: RuuviAirFirmwareDataModel?

    private let versionedFirmwares: [String: RuuviAirFirmwareDataModel]

    // MARK: - Predefined firmware type keys
    private enum KnownFirmwareType: String, CaseIterable {
        case latest, alpha, beta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // Decode known firmware types
        latest = try container
            .decodeIfPresent(
                RuuviAirFirmwareDataModel.self,
                forKey: .init(
                    stringValue: KnownFirmwareType.latest.rawValue
                )
            )
        alpha = try container
            .decodeIfPresent(
                RuuviAirFirmwareDataModel.self,
                forKey: .init(
                    stringValue: KnownFirmwareType.alpha.rawValue
                )
            )
        beta = try container
            .decodeIfPresent(
                RuuviAirFirmwareDataModel.self,
                forKey: .init(
                    stringValue: KnownFirmwareType.beta.rawValue
                )
            )

        // Decode versioned entries more efficiently
        var tempVersionedFirmwares: [String: RuuviAirFirmwareDataModel] = [:]
        let knownKeys = Set(KnownFirmwareType.allCases.map(\.rawValue))

        for key in container.allKeys where !knownKeys.contains(key.stringValue) {
            do {
                let firmware = try container.decode(RuuviAirFirmwareDataModel.self, forKey: key)
                tempVersionedFirmwares[key.stringValue] = firmware
            } catch {
                // Log error but continue processing other keys
                print("Warning: Failed to decode firmware for key '\(key.stringValue)': \(error)")
            }
        }

        versionedFirmwares = tempVersionedFirmwares
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)

        try container
            .encodeIfPresent(
                latest,
                forKey: .init(
                    stringValue: KnownFirmwareType.latest.rawValue
                )
            )
        try container
            .encodeIfPresent(
                alpha,
                forKey: .init(
                    stringValue: KnownFirmwareType.alpha.rawValue
                )
            )
        try container
            .encodeIfPresent(
                beta,
                forKey: .init(
                    stringValue: KnownFirmwareType.beta.rawValue
                )
            )

        for (
            key,
            firmware
        ) in versionedFirmwares {
            try container
                .encode(
                    firmware,
                    forKey: .init(
                        stringValue: key
                    )
                )
        }
    }

    func firmware(for type: RuuviDFUFirmwareType) -> RuuviAirFirmwareDataModel? {
        switch type {
        case .latest:
            return latest
        case .alpha:
            return alpha
        case .beta:
            return beta
        }
    }
}

struct RuuviAirFirmwareDataModel: Codable, Hashable {
    let version: String
    let url: String
    let createdAt: String
    let versionCode: Int
    let fileName: String
    let fwloader: String?
    let mcubootS1: String?
    let mcuboot: String?

    enum CodingKeys: String, CodingKey {
        case version
        case url
        case createdAt = "created_at"
        case versionCode
        case fileName
        case fwloader
        case mcubootS1 = "mcuboot_s1"
        case mcuboot
    }
}

/// Helper for dynamic JSON keys
struct DynamicCodingKeys: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

extension RuuviAirFirmwareData {
    func toLatestRelease(
        firmwareType: RuuviDFUFirmwareType = .latest
    ) -> LatestRelease? {
        guard let firmware = self.firmware(
            for: firmwareType
        ) else {
            return nil
        }

        return LatestRelease(
            version: firmware.version,
            assets: Self.makeAssets(from: firmware)
        )
    }

    private static func makeAssets(from firmware: RuuviAirFirmwareDataModel) -> [LatestReleaseAsset] {
        let filenames = [
            firmware.fileName,
            firmware.fwloader,
            firmware.mcubootS1,
            firmware.mcuboot,
        ]

        let uniqueFileNames = filenames.reduce(into: [String]()) { result, name in
            guard let name = name, !name.isEmpty, !result.contains(name) else {
                return
            }
            result.append(name)
        }

        return uniqueFileNames.map { name in
            LatestReleaseAsset(
                name: name,
                downloadUrlString: firmware.url + "/\(name)"
            )
        }
    }
}
