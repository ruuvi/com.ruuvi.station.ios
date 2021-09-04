import Foundation
import Future

public protocol RuuviServiceAuth {
    func logout() -> Future<Bool, RuuviServiceError>
}
