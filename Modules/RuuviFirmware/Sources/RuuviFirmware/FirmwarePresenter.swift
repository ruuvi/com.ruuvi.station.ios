import BTKit
import RuuviDFU
import SwiftUI
import UIKit

final class FirmwarePresenter: RuuviFirmware {
    weak var output: RuuviFirmwareOutput?
    var router: AnyObject?

    var viewController: UIViewController {
        if let view = self.weakView {
            return view
        } else {
            let view = UIHostingController(rootView: FirmwareView(viewModel: viewModel))
            self.weakView = view
            return view
        }
    }
    private weak var weakView: UIViewController?
    private let viewModel: FirmwareViewModel
    
    init(
        uuid: String,
        currentFirmware: String?,
        background: BTBackground,
        ruuviDFU: RuuviDFU,
        firmwareRepository: FirmwareRepository
    ) {
        let interactor = FirmwareInteractor(
            background: background,
            ruuviDFU: ruuviDFU,
            firmwareRepository: firmwareRepository
        )
        self.viewModel = FirmwareViewModel(
            uuid: uuid,
            currentFirmware: currentFirmware,
            interactor: interactor
        )
        self.viewModel.delegate = self
    }
}

extension FirmwarePresenter: FirmwareViewModelDelegate {
    func firmwareUpgradeDidFinishSuccessfully() {
        output?.ruuviFirmwareSuccessfullyUpgraded(self)
    }
}
