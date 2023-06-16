import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceCloudNotification {

    @discardableResult
    func set(token: String?,
             name: String?,
             data: String?,
             sound: RuuviAlertSound) -> Future<Int, RuuviServiceError>

    @discardableResult
    func set(sound: RuuviAlertSound,
             deviceName: String?) -> Future<Int, RuuviServiceError>

    @discardableResult
    func register(token: String,
                  type: String,
                  name: String?,
                  data: String?,
                  params: [String: String]?) -> Future<Int, RuuviServiceError>

    @discardableResult
    func unregister(token: String?,
                    tokenId: Int?) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func listTokens() -> Future<[RuuviCloudPNToken], RuuviServiceError>
}
