import Foundation

protocol OwnerViewOutput: AnyObject {
    func viewDidTapOnClaim()
    func update(with email: String)
}
