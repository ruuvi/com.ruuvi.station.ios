import Foundation
import SwiftUI
import Combine
import RuuviOntology
import RuuviPool

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
    private let ruuviPool: RuuviPool

    init(
        interactor: DFUInteractorInput,
        ruuviTag: RuuviTagSensor,
        ruuviPool: RuuviPool
    ) {
        self.interactor = interactor
        self.ruuviTag = ruuviTag
        self.ruuviPool = ruuviPool
        self.viewModel = DFUViewModel(
            interactor: interactor,
            ruuviTag: ruuviTag,
            ruuviPool: ruuviPool
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
