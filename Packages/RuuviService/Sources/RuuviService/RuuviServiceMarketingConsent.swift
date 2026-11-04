#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviStorage
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import RuuviCloud

public protocol RuuviServiceMarketingConsent {
    @discardableResult
    func getMarketingConsent() async throws(RuuviServiceError) -> RuuviCloudMarketingConsent
    @discardableResult
    func set(marketingPreference: Bool) async throws(RuuviServiceError) -> RuuviCloudMarketingConsent
}
