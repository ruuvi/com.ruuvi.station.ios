import Future
import RuuviCloud

public protocol RuuviServiceMarketingConsent {
    @discardableResult
    func getMarketingConsent() -> Future<RuuviCloudMarketingConsent, RuuviServiceError>
    @discardableResult
    func set(marketingPreference: Bool) -> Future<RuuviCloudMarketingConsent, RuuviServiceError>
}
