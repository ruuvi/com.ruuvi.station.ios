import Foundation
import RuuviOntology
import RuuviService
import RuuviPresenters
import RuuviLocal

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
        guard let ruuviTag = ruuviTag else { return }
        view?.updateView(
            claimedAndOwned: ruuviTag.isClaimed && ruuviTag.isOwner,
            locallyOwned: !ruuviTag.isClaimed && ruuviTag.isOwner,
            shared: !ruuviTag.isOwner)
    }

    func viewDidTriggerRemoveTag() {
        view?.showHistoryDataRemovalConfirmationDialog()
    }

    func viewDidConfirmTagRemoval(with removeCloudData: Bool) {
        guard let ruuviTag = ruuviTag else { return }
        ruuviOwnershipService.remove(
            sensor: ruuviTag,
            removeCloudHistory: removeCloudData
        ).on(success: { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output?.sensorRemovalDidRemoveTag(
                module: sSelf,
                ruuviTag: ruuviTag
            )
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidDismiss() {
        router?.dismiss(completion: nil)
    }
}
