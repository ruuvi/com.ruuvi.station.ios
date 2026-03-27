import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPresenters
import RuuviService

final class SensorRemovalPresenter: SensorRemovalModuleInput {
    weak var view: SensorRemovalViewInput?
    weak var output: SensorRemovalModuleOutput?
    var router: SensorRemovalRouterInput?
    var ruuviOwnershipService: RuuviServiceOwnership!
    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!

    private var ruuviTag: RuuviTagSensor?

    func configure(
        ruuviTag: RuuviTagSensor,
        output: SensorRemovalModuleOutput
    ) {
        self.ruuviTag = ruuviTag
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        router?.dismiss(completion: completion)
    }
}

extension SensorRemovalPresenter: SensorRemovalViewOutput {
    func viewDidLoad() {
        guard let ruuviTag else { return }
        view?.updateView(ownership: ruuviTag.ownership)
    }

    func viewDidTriggerRemoveTag() {
        view?.showHistoryDataRemovalConfirmationDialog()
    }

    func viewDidConfirmTagRemoval(with removeCloudData: Bool) {
        guard let ruuviTag else { return }
        Task { [weak self] in
            do {
                _ = try await self?.ruuviOwnershipService.remove(
                    sensor: ruuviTag,
                    removeCloudHistory: removeCloudData
                )
                guard let self else { return }
                self.output?.sensorRemovalDidRemoveTag(
                    module: self,
                    ruuviTag: ruuviTag
                )
            } catch {
                self?.errorPresenter.present(error: error)
            }
        }
    }

    func viewDidDismiss() {
        router?.dismiss(completion: nil)
    }
}
