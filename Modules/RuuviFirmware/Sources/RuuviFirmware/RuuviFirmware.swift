import UIKit

public protocol RuuviFirmware: AnyObject {
    var viewController: UIViewController { get }
    var router: AnyObject? { get set }
    var output: RuuviFirmwareOutput? { get set }
}

public protocol RuuviFirmwareOutput: AnyObject {
    func ruuviFirmwareSuccessfullyUpgraded(_ ruuviDiscover: RuuviFirmware)
}
