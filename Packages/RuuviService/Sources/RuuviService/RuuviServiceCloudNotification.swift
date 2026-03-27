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
    ) async throws -> Int

    @discardableResult
    func set(
        sound: RuuviAlertSound,
        language: Language,
        deviceName: String?
    ) async throws -> Int

    @discardableResult
    func register(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int

    @discardableResult
    func unregister(
        token: String?,
        tokenId: Int?
    ) async throws -> Bool

    @discardableResult
    func listTokens() async throws -> [RuuviCloudPNToken]
}
