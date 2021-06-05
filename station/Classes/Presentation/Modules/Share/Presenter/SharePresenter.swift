import Foundation
import Future
import UIKit
import RuuviService
import RuuviOntology

class SharePresenter {
    weak var view: ShareViewInput!
    var router: ShareRouterInput!

    var activityPresenter: ActivityPresenter!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
    var ruuviOwnershipService: RuuviServiceOwnership!

    private var sensor: RuuviTagSensor!
    private let maxShareCount: Int = 10
    private var viewModel: ShareViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - ShareViewOutput
extension SharePresenter: ShareViewOutput {
    func viewDidLoad() {
        fetchShared()
    }

    func viewDidTapSendButton(email: String?) {
        guard let email = email,
              !email.isEmpty else {
            return
        }

        activityPresenter.increment()
        ruuviOwnershipService
            .share(macId: sensor.id.mac, with: email)
            .on(success: { [weak self] _ in
                self?.fetchShared()
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func unshareTag(_ email: String) {
        activityPresenter.increment()
        ruuviOwnershipService
            .unshare(macId: sensor.id.mac, with: email)
            .on(success: { [weak self] _ in
                self?.fetchShared()
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    func viewDidTapUnshareEmail(_ email: String?) {
        guard let email = email,
              !email.isEmpty else {
            return
        }
        let title: String? = nil
        let message = String(format: "SharePresenter.UnshareSensor.Message".localized(), email)
        let confirmActionTitle = "Yes".localized()
        let cancelActionTitle = "No".localized()
        let confirmAction = UIAlertAction(title: confirmActionTitle,
                                          style: .default) { [weak self] (_) in
            self?.unshareTag(email)
        }

        let cancleAction = UIAlertAction(title: cancelActionTitle,
                                         style: .cancel,
                                         handler: nil)
        let actions = [ confirmAction, cancleAction ]
        let alertViewModel = AlertViewModel(title: title,
                                            message: message,
                                            style: .alert,
                                            actions: actions)
        alertPresenter.showAlert(alertViewModel)
    }
}
// MARK: - ShareModuleInput
extension SharePresenter: ShareModuleInput {
    func configure(sensor: RuuviTagSensor) {
        self.sensor = sensor
        viewModel = ShareViewModel(maxCount: self.maxShareCount)
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}
// MARK: - Private
extension SharePresenter {
    private func fetchShared() {
        activityPresenter.increment()
        ruuviOwnershipService
            .loadShared(for: sensor)
            .on(success: { [weak self] shareableSensors in
                self?.filterEmails(shareableSensors)
                self?.view.clearInput()
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func filterEmails(_ sensors: Set<AnyShareableSensor>) {
        viewModel.sharedEmails.value = sensors
            .first(where: {
                $0.id == sensor.id
            })?.sharedTo
        view.reloadTableView()
    }
}
