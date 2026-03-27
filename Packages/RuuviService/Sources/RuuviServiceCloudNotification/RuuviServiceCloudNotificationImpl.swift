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
    public func set(
        token: String?,
        name: String?,
        data: String?,
        language: Language,
        sound: RuuviAlertSound
    ) async throws -> Int {
        guard ruuviUser.isAuthorized, let token else {
            return pnManager.fcmTokenId ?? 0
        }

        var refreshable = false
        if let lastRefreshed = pnManager.fcmTokenLastRefreshed {
            if let daysFromNow = lastRefreshed.numberOfDaysFromNow(),
               daysFromNow > 7 {
                refreshable = true
            }
        } else {
            refreshable = true
        }

        guard refreshable else {
            return pnManager.fcmTokenId ?? 0
        }

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
        pnManager.fcmTokenId = tokenId
        pnManager.fcmToken = token
        pnManager.fcmTokenLastRefreshed = Date()
        return tokenId
    }

    @discardableResult
    public func set(
        sound: RuuviAlertSound,
        language: Language,
        deviceName: String?
    ) async throws -> Int {
        guard ruuviUser.isAuthorized, let token = pnManager.fcmToken else {
            return pnManager.fcmTokenId ?? 0
        }

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
        pnManager.fcmTokenId = tokenId
        pnManager.fcmToken = token
        pnManager.fcmTokenLastRefreshed = Date()
        return tokenId
    }

    @discardableResult
    public func register(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int {
        return try await RuuviServiceError.perform {
            try await self.cloud.registerPNToken(
                token: token,
                type: type,
                name: name,
                data: data,
                params: params
            )
        }
    }

    @discardableResult
    public func unregister(
        token: String?,
        tokenId: Int?
    ) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.unregisterPNToken(
                token: token,
                tokenId: tokenId
            )
        }
    }

    @discardableResult
    public func listTokens() async throws -> [RuuviCloudPNToken] {
        return try await RuuviServiceError.perform {
            try await self.cloud.listPNTokens()
        }
    }
}

extension Date {
    func numberOfDaysFromNow() -> Int? {
        let numberOfDays = Calendar.current.dateComponents([.day], from: self, to: Date())
        return numberOfDays.day
    }
}
