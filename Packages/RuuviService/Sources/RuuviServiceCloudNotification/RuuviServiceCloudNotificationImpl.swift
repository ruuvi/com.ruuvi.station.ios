#if SWIFT_PACKAGE
    import RuuviService
    import RuuviCloudApi
#endif
import Foundation
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviStorage
import RuuviUser

public final class RuuviServiceCloudNotificationImpl: RuuviServiceCloudNotification {
    private let cloud: RuuviCloud
    private let pool: RuuviPool
    private let storage: RuuviStorage
    private let ruuviUser: RuuviUser
    private var pnManager: RuuviCorePN

    public init(
        cloud: RuuviCloud,
        pool: RuuviPool,
        storage: RuuviStorage,
        ruuviUser: RuuviUser,
        pnManager: RuuviCorePN
    ) {
        self.cloud = cloud
        self.pool = pool
        self.storage = storage
        self.ruuviUser = ruuviUser
        self.pnManager = pnManager
    }

    @discardableResult
    @MainActor
    public func set(
        token: String?,
        name: String?,
        data: String?,
        language: Language,
        sound: RuuviAlertSound
    ) async throws(RuuviServiceError) -> Int {
        var outcome: Result<Int, RuuviServiceError>
        guard ruuviUser.isAuthorized else { throw .ruuviCloud(.notAuthorized) }
        guard let token else { throw .ruuviCloud(.api(.badParameters)) }

        var refreshable = false
        if let lastRefreshed = pnManager.fcmTokenLastRefreshed {
            if let daysFromNow = lastRefreshed.numberOfDaysFromNow(),
                daysFromNow > 7
            {
                refreshable = true
            }
        } else {
            refreshable = true
        }

        if !refreshable, pnManager.fcmToken == token, let tokenId = pnManager.fcmTokenId {
            return tokenId
        }

        do {
            let tokenId = try await register(
                token: token,
                type: "ios",
                name: name,
                data: data,
                params: [
                    RuuviCloudPNTokenRegisterRequestParamsKey.sound.rawValue: sound.rawValue,
                    RuuviCloudPNTokenRegisterRequestParamsKey.language.rawValue: language.rawValue,
                ]
            )
            self.pnManager.fcmTokenId = tokenId
            self.pnManager.fcmToken = token
            self.pnManager.fcmTokenLastRefreshed = Date()
            outcome = .success(tokenId)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(
        sound: RuuviAlertSound,
        language: Language,
        deviceName: String?
    ) async throws(RuuviServiceError) -> Int {
        var outcome: Result<Int, RuuviServiceError>
        guard ruuviUser.isAuthorized else { throw .ruuviCloud(.notAuthorized) }
        guard let token = pnManager.fcmToken else { throw .ruuviCloud(.api(.badParameters)) }

        do {
            let tokenId = try await register(
                token: token,
                type: "ios",
                name: deviceName,
                data: nil,
                params: [
                    RuuviCloudPNTokenRegisterRequestParamsKey.sound.rawValue: sound.rawValue,
                    RuuviCloudPNTokenRegisterRequestParamsKey.language.rawValue: language.rawValue,
                ]
            )
            self.pnManager.fcmTokenId = tokenId
            self.pnManager.fcmToken = token
            self.pnManager.fcmTokenLastRefreshed = Date()
            outcome = .success(tokenId)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func register(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviServiceError) -> Int {
        var outcome: Result<Int, RuuviServiceError>
        do {
            let tokenId = try await cloud.registerPNToken(
                token: token,
                type: type,
                name: name,
                data: data,
                params: params
            )
            outcome = .success(tokenId)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func unregister(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviServiceError) -> Bool {
        var outcome: Result<Bool, RuuviServiceError>
        do {
            let success = try await cloud.unregisterPNToken(
                token: token,
                tokenId: tokenId
            )
            outcome = .success(success)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func listTokens() async throws(RuuviServiceError) -> [RuuviCloudPNToken] {
        var outcome: Result<[RuuviCloudPNToken], RuuviServiceError>
        do {
            let tokens = try await cloud.listPNTokens()
            outcome = .success(tokens)
        } catch let error {
            outcome = .failure(.ruuviCloud(error))
        }
        return try outcome.get()
    }
}

extension Date {
    func numberOfDaysFromNow() -> Int? {
        let numberOfDays = Calendar.current.dateComponents([.day], from: self, to: Date())
        return numberOfDays.day
    }
}
