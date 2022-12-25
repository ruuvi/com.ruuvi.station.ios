import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceCloudNotification {

    @discardableResult
    func set(token: String?,
             name: String?,
             data: String?) -> Future<Int, RuuviServiceError>

    @discardableResult
    func register(token: String,
                  type: String,
                  name: String?,
                  data: String?) -> Future<Int, RuuviServiceError>

    @discardableResult
    func unregister(token: String?,
                    tokenId: Int?) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func listTokens() -> Future<[RuuviCloudPNToken], RuuviServiceError>
}
