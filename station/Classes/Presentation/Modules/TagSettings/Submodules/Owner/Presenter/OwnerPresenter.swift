import Foundation
import RuuviOntology
import RuuviService

final class OwnerPresenter: OwnerModuleInput {
    weak var view: OwnerViewInput!
    var router: OwnerRouterInput!
    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!
    var ruuviOwnershipService: RuuviServiceOwnership!
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
}
