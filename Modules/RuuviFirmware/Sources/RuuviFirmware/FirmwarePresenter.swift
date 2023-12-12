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
            let viewModel = FirmwareViewModel(
                uuid: uuid,
                currentFirmware: currentFirmware,
                interactor: interactor
            )
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

    init(
        uuid: String,
        currentFirmware: String?,
        background: BTBackground,
        ruuviDFU: RuuviDFU,
        firmwareRepository: FirmwareRepository
    ) {
        self.uuid = uuid
        self.currentFirmware = currentFirmware
        interactor = FirmwareInteractor(
            background: background,
            ruuviDFU: ruuviDFU,
            firmwareRepository: firmwareRepository
        )
    }
}

extension FirmwarePresenter: FirmwareViewModelOutput {
    func firmwareUpgradeDidFinishSuccessfully() {
        output?.ruuviFirmwareSuccessfullyUpgraded(self)
    }
}
