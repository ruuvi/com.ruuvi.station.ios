import Foundation
import RuuviOntology
import RuuviService
import RuuviPool
import RuuviStorage

final class OwnerPresenter: OwnerModuleInput {
    weak var view: OwnerViewInput!
    var router: OwnerRouterInput!
    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var ruuviStorage: RuuviStorage!
    var ruuviPool: RuuviPool!

    private var ruuviTag: RuuviTagSensor!
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }

    func configure(ruuviTag: RuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }
}

extension OwnerPresenter: OwnerViewOutput {
    /// This method is responsible for claiming the sensor
    func viewDidTapOnClaim() {
        isLoading = true
        ruuviOwnershipService
            .claim(sensor: ruuviTag)
            .on(success: { [weak self] _ in
                self?.router.dismiss()
            }, failure: { [weak self] error in
                switch error {
                case .ruuviCloud(.api(.claim(let claimError))):
                    self?.view.showSensorAlreadyClaimedError(error: claimError.code, email: claimError.error.email())
                default:
                    return
                }
            }, completion: { [weak self] in
                self?.isLoading = false
            })
    }
    /// Update the tag with owner information
    func update(with email: String) {
        ruuviStorage.readAll().on(success: { [weak self] localSensors in
            guard let sSelf = self else { return }
            if let sensor = localSensors.first(where: {$0.id == sSelf.ruuviTag.id }) {
                sSelf.ruuviPool.update(sensor
                                        .with(owner: email))
            }
        })
    }
}
