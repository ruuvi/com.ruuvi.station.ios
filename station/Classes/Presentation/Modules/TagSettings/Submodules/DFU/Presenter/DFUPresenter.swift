import Foundation
import SwiftUI
import Combine
import RuuviOntology

final class DFUPresenter: DFUModuleInput {
    // SwiftUI
    var viewController: UIViewController {
        if let view = self.weakView {
            return view
        } else {
            let view = UIHostingController(rootView: DFUUIView(viewModel: viewModel))
            self.weakView = view
            return view
        }

    }
    lazy var viewModel: DFUViewModel = {
        return DFUViewModel(interactor: interactor, ruuviTag: ruuviTag)
    }()
    private weak var weakView: UIViewController?
    private var interactor: DFUInteractorInput
    private var ruuviTag: RuuviTagSensor

    // VIP
    weak var view: DFUViewInput?
    var errorPresenter: ErrorPresenter!

    private var disposeBag: Set<AnyCancellable> = []

    init(
        interactor: DFUInteractorInput,
        ruuviTag: RuuviTagSensor
    ) {
        self.interactor = interactor
        self.ruuviTag = ruuviTag
    }

    func configure(ruuviTag: RuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }
}

extension DFUPresenter: DFUViewOutput {
    func viewDidLoad() {
        interactor.loadLatestRelease()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    self?.errorPresenter.present(error: error)
                case .finished:
                    break
                }
            }, receiveValue: { firmwareVersion in
                print(firmwareVersion)
            }).store(in: &disposeBag)
    }
}
