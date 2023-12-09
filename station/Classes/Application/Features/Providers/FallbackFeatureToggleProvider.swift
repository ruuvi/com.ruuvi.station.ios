import Foundation

public final class FallbackFeatureToggleProvider: FeatureToggleProvider {
    public func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback) {
        let configuration = FallbackFeatureToggleProvider.loadConfiguration() ?? []

        completion(configuration)
    }
}

extension FallbackFeatureToggleProvider {
    static let jsonContainerName: String = "featureToggles"
    static let configurationName: String = "FeatureToggles"
    static let configurationType: String = "json"

    static func loadConfiguration() -> [FeatureToggle]? {
        guard let configurationURL = bundledConfigurationURL(),
              let data = try? Data(contentsOf: configurationURL)
        else {
            return nil
        }
        return parseConfiguration(data: data)
    }

    static func parseConfiguration(data: Data) -> ParsingServiceResult? {
        JSONParsingService().parse(data, containerName: jsonContainerName)
    }

    static func bundledConfigurationURL() -> URL? {
        Bundle.main.url(forResource: configurationName, withExtension: configurationType)
    }
}

typealias ParsingServiceResult = [FeatureToggle]

protocol ParsingService {
    func parse(_ data: Data, containerName: String) -> ParsingServiceResult?
}

public struct JSONParsingService: ParsingService {
    func parse(_ data: Data, containerName: String) -> ParsingServiceResult? {
        var toggleData = data

        if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
           let jsonContainer = json as? [String: Any],
           let featureToggles = jsonContainer[containerName],
           let featureTogglesData = try? JSONSerialization.data(withJSONObject: featureToggles) {
            toggleData = featureTogglesData
        }

        return try? JSONDecoder().decode([FeatureToggle].self, from: toggleData)
    }
}
