import Foundation
import RuuviOntology
import RuuviService
import RuuviPresenters
import RuuviLocal
import UIKit

final class DevicesPresenter: DevicesModuleInput {
    var interactor: DevicesInteractorInput!

    var viewController: UIViewController {
        if let view = self.weakView {
            return view
        } else {
            let view = DevicesTableViewController()
            view.output = self
            self.weakView = view
            return view
        }

    }
    private weak var weakView: UIViewController?

    private var viewModels: [DevicesViewModel] = [] {
        didSet {
            if let view = weakView as? DevicesTableViewController {
                view.viewModels = viewModels
            }
        }
    }
}

extension DevicesPresenter: DevicesViewOutput {
    func viewDidLoad() {
        // No op.
    }

    func viewWillAppear() {
        fetchDevices()
    }

    func viewDidTapDevice(viewModel: DevicesViewModel) {
        if let view = weakView as? DevicesTableViewController {
            view.showTokenIdDialog(for: viewModel)
        }
    }
}

extension DevicesPresenter: DevicesInteractorOutput {
    func interactorDidUpdate(tokens: [RuuviCloudPNToken]) {
        let viewModels = tokens.compactMap({ (token) -> DevicesViewModel in
            let viewModel = DevicesViewModel()
            viewModel.id.value = token.id
            viewModel.lastAccessed.value = token.lastAccessed
            viewModel.name.value = token.name
            return viewModel
        })
        self.viewModels = viewModels
    }

    func interactorDidError(_ error: RUError) {
        if let view = weakView as? DevicesTableViewController {
            view.showTokenFetchError(with: error)
        }
    }
}

extension DevicesPresenter {
    private func fetchDevices() {
        interactor.fetchDevices()
    }
}
