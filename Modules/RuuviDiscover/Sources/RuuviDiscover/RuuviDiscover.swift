import UIKit
import RuuviOntology

public protocol RuuviDiscover: AnyObject {
    var viewController: UIViewController { get }
    var router: AnyObject? { get set }
    var output: RuuviDiscoverOutput? { get set }

    func onDidPick(location: Location)
}

public protocol RuuviDiscoverOutput: AnyObject {
    func ruuviDiscoverWantsClose(_ ruuviDiscover: RuuviDiscover)
    func ruuviDiscoverWantsBuySensors(_ ruuviDiscover: RuuviDiscover)
    func ruuviDiscoverWantsPickLocation(_ ruuviDiscover: RuuviDiscover)
    func ruuvi(discover: RuuviDiscover, didAdd virtualSensor: AnyVirtualTagSensor)
    func ruuvi(discover: RuuviDiscover, didAdd ruuviTag: AnyRuuviTagSensor)
}
