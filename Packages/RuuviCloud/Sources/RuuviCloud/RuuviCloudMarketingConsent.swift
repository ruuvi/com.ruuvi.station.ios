import Foundation

public enum RuuviCloudMarketingConsentStatus: String, Codable, Equatable, Sendable {
    case subscribed
    case unsubscribed
    case unconfirmed
    case bounced
    case softBounced = "soft_bounced"
    case complained
    case notFound = "not_found"
}

public struct RuuviCloudMarketingConsent: Codable, Equatable, Sendable {
    public let consent: Bool
    public let status: RuuviCloudMarketingConsentStatus

    public init(
        consent: Bool,
        status: RuuviCloudMarketingConsentStatus
    ) {
        self.consent = consent
        self.status = status
    }
}
