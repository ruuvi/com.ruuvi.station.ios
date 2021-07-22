import UIKit

public protocol RuuviDiscover: AnyObject {
    var viewController: UIViewController { get }
    var router: AnyObject? { get set }
}

public protocol RuuviDiscoverOutput: AnyObject {
    func ruuviDiscoverWantsClose(_ ruuviDiscover: RuuviDiscover)
}
