import Foundation

public struct RuuviCloudApiGetMarketingConsentRequest: Encodable {
    public init() {}
}

public struct RuuviCloudApiSetMarketingConsentRequest: Encodable {
    public let consent: Bool
    public let silent: Bool

    public init(consent: Bool, silent: Bool) {
        self.consent = consent
        self.silent = silent
    }
}
