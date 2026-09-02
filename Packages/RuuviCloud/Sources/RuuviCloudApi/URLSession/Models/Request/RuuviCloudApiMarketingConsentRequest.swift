import Foundation

public struct RuuviCloudApiGetMarketingConsentRequest: Encodable {
    public init() {}
}

public struct RuuviCloudApiSetMarketingConsentRequest: Encodable {
    public let consent: Bool
    public let silent: Bool
    public let joiningSource: String
    public let language: String

    public init(consent: Bool, silent: Bool, language: String) {
        self.consent = consent
        self.silent = silent
        joiningSource = "ios"
        self.language = Self.sendyLanguageCode(from: language)
    }

    private static func sendyLanguageCode(from language: String) -> String {
        let code = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(
            whereSeparator: { $0 == "-" || $0 == "_" }
            )
            .first?
            .uppercased() ?? ""
        let letters = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        )
        guard code.count == 2,
              code.unicodeScalars.allSatisfy(letters.contains)
        else {
            return "EN"
        }
        return code
    }
}
