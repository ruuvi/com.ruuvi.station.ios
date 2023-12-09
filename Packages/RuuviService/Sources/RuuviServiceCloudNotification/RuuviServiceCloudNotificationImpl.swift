import Foundation
import Future
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviService
import RuuviStorage
import RuuviUser
#if canImport(RuuviCloudApi)
    import RuuviCloudApi
#endif

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
    ) -> Future<Int, RuuviServiceError> {
        let promise = Promise<Int, RuuviServiceError>()
        guard ruuviUser.isAuthorized, let token
        else {
            return promise.future
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

        guard refreshable
        else {
            return promise.future
        }

        register(
            token: token,
            type: "ios",
            name: name,
            data: data,
            params: [
                RuuviCloudPNTokenRegisterRequestParamsKey.sound.rawValue: sound.rawValue,
                RuuviCloudPNTokenRegisterRequestParamsKey.language.rawValue: language.rawValue,
            ]
        )
        .on(success: { [weak self] tokenId in
            self?.pnManager.fcmTokenId = tokenId
            self?.pnManager.fcmToken = token
            self?.pnManager.fcmTokenLastRefreshed = Date()
            promise.succeed(value: tokenId)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    @discardableResult
    public func set(
        sound: RuuviAlertSound,
        language: Language,
        deviceName: String?
    ) -> Future<Int, RuuviServiceError> {
        let promise = Promise<Int, RuuviServiceError>()
        guard ruuviUser.isAuthorized, let token = pnManager.fcmToken
        else {
            return promise.future
        }

        register(
            token: token,
            type: "ios",
            name: deviceName,
            data: nil,
            params: [
                RuuviCloudPNTokenRegisterRequestParamsKey.sound.rawValue: sound.rawValue,
                RuuviCloudPNTokenRegisterRequestParamsKey.language.rawValue: language.rawValue,
            ]
        )
        .on(success: { [weak self] tokenId in
            self?.pnManager.fcmTokenId = tokenId
            self?.pnManager.fcmToken = token
            self?.pnManager.fcmTokenLastRefreshed = Date()
            promise.succeed(value: tokenId)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    @discardableResult
    public func register(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) -> Future<Int, RuuviServiceError> {
        let promise = Promise<Int, RuuviServiceError>()
        cloud.registerPNToken(
            token: token,
            type: type,
            name: name,
            data: data,
            params: params
        )
        .on(success: { tokenId in
            promise.succeed(value: tokenId)
        }, failure: { error in
            promise.fail(error: .ruuviCloud(error))
        })
        return promise.future
    }

    @discardableResult
    public func unregister(
        token: String?,
        tokenId: Int?
    ) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        cloud.unregisterPNToken(
            token: token,
            tokenId: tokenId
        )
        .on(success: { success in
            promise.succeed(value: success)
        }, failure: { error in
            promise.fail(error: .ruuviCloud(error))
        })
        return promise.future
    }

    @discardableResult
    public func listTokens() -> Future<[RuuviCloudPNToken], RuuviServiceError> {
        let promise = Promise<[RuuviCloudPNToken], RuuviServiceError>()
        cloud.listPNTokens()
            .on(success: { tokens in
                promise.succeed(value: tokens)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }
}

extension Date {
    func numberOfDaysFromNow() -> Int? {
        let numberOfDays = Calendar.current.dateComponents([.day], from: self, to: Date())
        return numberOfDays.day
    }
}
