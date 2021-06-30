import Foundation
import Combine
import RuuviOntology

final class DFUPresenter: DFUModuleInput {
    weak var view: DFUViewInput?
    var errorPresenter: ErrorPresenter!
    var interactor: DFUInteractorInput!
    private var ruuviTag: RuuviTagSensor!
    private var disposeBag: Set<AnyCancellable> = []

    func configure(ruuviTag: RuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }
}

extension DFUPresenter: DFUViewOutput {
    func viewDidLoad() {
        interactor.fetchLatestRuuviTagFirmwareVersion()
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
