import Foundation
import RuuviDiscover
import RuuviOntology
import BTKit
import RuuviLocationPicker

protocol DiscoverRouterDelegate: AnyObject {
    func discoverRouterWantsClose(_ router: DiscoverRouter)
    func discoverRouterWantsCloseWithRuuviTagNavigation(
        _ router: DiscoverRouter,
        ruuviTag: RuuviTagSensor
    )
}

final class DiscoverRouter {
    var viewController: UIViewController {
        return self.discover.viewController
    }
    weak var delegate: DiscoverRouterDelegate?

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

extension DiscoverRouter: RuuviLocationPickerOutput {
    func ruuviLocationPickerWantsClose(_ ruuviLocationPicker: RuuviLocationPicker) {
        ruuviLocationPicker.viewController.dismiss(animated: true)
    }

    func ruuvi(locationPicker: RuuviLocationPicker, didPick location: Location) {
        locationPicker.viewController.dismiss(animated: true) { [weak self] in
            self?.discover.onDidPick(location: location)
        }
    }
}

extension DiscoverRouter: RuuviDiscoverOutput {
    func ruuviDiscoverWantsClose(_ ruuviDiscover: RuuviDiscover) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover: RuuviDiscover, didAdd ruuviTag: AnyRuuviTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover: RuuviDiscover, didSelectFromNFC ruuviTag: RuuviTagSensor) {
        delegate?.discoverRouterWantsCloseWithRuuviTagNavigation(self, ruuviTag: ruuviTag)
    }
}

extension DiscoverRouter {
    // Will be deprecated in near future. Currently retained to support already
    // added web tags.
    func ruuviDiscoverWantsPickLocation(_ ruuviDiscover: RuuviDiscover) {
        let navigation = UINavigationController(rootViewController: locationPicker.viewController)
        viewController.present(navigation, animated: true)
    }

    func ruuvi(discover: RuuviDiscover, didAdd virtualSensor: AnyVirtualTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }
}
