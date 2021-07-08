import Foundation
import SwiftUI
import Combine
import RuuviOntology

final class DFUPresenter: DFUModuleInput {
    var viewController: UIViewController {
        if let view = self.weakView {
            return view
        } else {
            let view = UIHostingController(rootView: DFUUIView(viewModel: viewModel))
            self.weakView = view
            return view
        }

    }
    private weak var weakView: UIViewController?
    private let viewModel: DFUViewModel
    private let interactor: DFUInteractorInput
    private let ruuviTag: RuuviTagSensor

    init(
        interactor: DFUInteractorInput,
        ruuviTag: RuuviTagSensor
    ) {
        self.interactor = interactor
        self.ruuviTag = ruuviTag
        self.viewModel = DFUViewModel(
            interactor: interactor,
            ruuviTag: ruuviTag
        )
    }

    func isSafeToDismiss() -> Bool {
        switch viewModel.state {
        case .flashing:
            return false
        default:
            return true
        }
    }
}
