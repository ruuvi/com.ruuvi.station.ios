import BTKit
import RuuviDFU
import SwiftUI
import UIKit

final class FirmwarePresenter: RuuviFirmware {
    weak var output: RuuviFirmwareOutput?
    var router: AnyObject?

    var viewController: UIViewController {
        if let view = weakView {
            return view
        } else {
            viewModel.output = self
            let view = UIHostingController(rootView: FirmwareView(viewModel: viewModel))
            weakView = view
            return view
        }
    }

    private weak var weakView: UIViewController?
    private let interactor: FirmwareInteractor
    private let uuid: String
    private let currentFirmware: String?
    private lazy var viewModel: FirmwareViewModel = {
        FirmwareViewModel(
            uuid: uuid,
            currentFirmware: currentFirmware,
            interactor: interactor
        )
    }()

    init(
        uuid: String,
        currentFirmware: String?,
        background: BTBackground,
        foreground: BTForeground,
        ruuviDFU: RuuviDFU,
        firmwareRepository: FirmwareRepository
    ) {
        self.uuid = uuid
        self.currentFirmware = currentFirmware
        interactor = FirmwareInteractor(
            background: background,
            foreground: foreground,
            ruuviDFU: ruuviDFU,
            firmwareRepository: firmwareRepository
        )
        interactor.ensureBatteryHasEnoughPower(uuid: uuid)
    }

    func isSafeToDismiss() -> Bool {
        switch viewModel.state {
        case .flashing:
            false
        default:
            true
        }
    }
}

extension FirmwarePresenter: FirmwareViewModelOutput {
    func firmwareUpgradeDidFinishSuccessfully() {
        output?.ruuviFirmwareSuccessfullyUpgraded(self)
    }
}
