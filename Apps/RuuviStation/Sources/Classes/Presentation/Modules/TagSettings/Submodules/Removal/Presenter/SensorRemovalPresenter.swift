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
        Task { @MainActor [weak self, ruuviOwnershipService = ruuviOwnershipService!, ruuviTag = ruuviTag] in
            do throws(RuuviServiceError) {
                let value = try await ruuviOwnershipService.remove(
                    sensor: ruuviTag,
                    removeCloudHistory: removeCloudData
                )
                ({ [weak self] _ in
                    guard let sSelf = self else { return }
                    sSelf.output?.sensorRemovalDidRemoveTag(
                        module: sSelf,
                        ruuviTag: ruuviTag
                    )
                })(value)
            } catch {
                ({ [weak self] error in
                    self?.errorPresenter.present(error: error)
                })(error)
            }
        }
    }

    func viewDidDismiss() {
        router?.dismiss(completion: nil)
    }
}
