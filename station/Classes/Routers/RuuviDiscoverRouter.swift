import Foundation
import RuuviDiscover
import RuuviOntology
import BTKit
import RuuviLocationPicker

protocol RuuviDiscoverRouterDelegate: AnyObject {
    func discoverRouterWantsClose(_ router: RuuviDiscoverRouter)
}

final class RuuviDiscoverRouter {
    var viewController: UIViewController {
        return self.discover.viewController
    }
    weak var delegate: RuuviDiscoverRouterDelegate?

    // modules
    private var discover: RuuviDiscover {
        if let discover = self.weakDiscover {
            return discover
        } else {
            let r = AppAssembly.shared.assembler.resolver
            let discover = r.resolve(RuuviDiscover.self)!
            discover.router = self
            discover.output = self
            self.weakDiscover = discover
            return discover
        }
    }
    private weak var weakDiscover: RuuviDiscover?

    private var locationPicker: RuuviLocationPicker {
        if let locationPicker = self.weakLocationPicker {
            return locationPicker
        } else {
            let r = AppAssembly.shared.assembler.resolver
            let locationPicker = r.resolve(RuuviLocationPicker.self)!
            locationPicker.router = self
            locationPicker.output = self
            self.weakLocationPicker = locationPicker
            return locationPicker
        }
    }
    private weak var weakLocationPicker: RuuviLocationPicker?
}

extension RuuviDiscoverRouter: RuuviLocationPickerOutput {
    func ruuviLocationPickerWantsClose(_ ruuviLocationPicker: RuuviLocationPicker) {
        ruuviLocationPicker.viewController.dismiss(animated: true)
    }

    func ruuvi(locationPicker: RuuviLocationPicker, didPick location: Location) {
        locationPicker.viewController.dismiss(animated: true) { [weak self] in
            self?.discover.onDidPick(location: location)
        }
    }
}

extension RuuviDiscoverRouter: RuuviDiscoverOutput {
    func ruuviDiscoverWantsBuySensors(_ ruuviDiscover: RuuviDiscover) {
        UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
    }

    func ruuviDiscoverWantsPickLocation(_ ruuviDiscover: RuuviDiscover) {
        viewController.present(locationPicker.viewController, animated: true)
    }

    func ruuviDiscoverWantsClose(_ ruuviDiscover: RuuviDiscover) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover: RuuviDiscover, didAdd virtualSensor: AnyVirtualTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover: RuuviDiscover, didAdd ruuviTag: AnyRuuviTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }
}
