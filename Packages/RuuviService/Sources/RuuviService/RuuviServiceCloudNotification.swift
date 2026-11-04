#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviCloud
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import Foundation
import RuuviOntology

public protocol RuuviServiceCloudNotification {
    @discardableResult
    func set(
        token: String?,
        name: String?,
        data: String?,
        language: Language,
        sound: RuuviAlertSound
    ) async throws(RuuviServiceError) -> Int

    @discardableResult
    func set(
        sound: RuuviAlertSound,
        language: Language,
        deviceName: String?
    ) async throws(RuuviServiceError) -> Int

    @discardableResult
    func register(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviServiceError) -> Int

    @discardableResult
    func unregister(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func listTokens() async throws(RuuviServiceError) -> [RuuviCloudPNToken]
}
