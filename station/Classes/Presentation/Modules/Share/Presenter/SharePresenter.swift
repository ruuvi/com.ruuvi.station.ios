import Foundation
import Future
import UIKit
import RuuviService

class SharePresenter {
    weak var view: ShareViewInput!
    var router: ShareRouterInput!

    var activityPresenter: ActivityPresenter!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
    var networkService: RuuviNetworkUserApi!
    var ruuviOwnershipService: RuuviServiceOwnership!

    private var ruuviTagId: String!
    private let maxShareCount: Int = 3
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
            .share(macId: ruuviTagId.mac, with: email)
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
            .unshare(macId: ruuviTagId.mac, with: email)
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
        let title = "SharePresenter.UnshareSensor.Title".localized()
        let message = String(format: "SharePresenter.UnshareSensor.Message".localized(), email)

        let confirmActionTitle = "SharePresenter.UnshareSensor.ConfirmAction".localized()
        let cancelActionTitle = "SharePresenter.UnshareSensor.CancelAction".localized()
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
    func configure(ruuviTagId: String) {
        self.ruuviTagId = ruuviTagId
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
        networkService.shared(.init())
            .on(success: { [weak self] response in
                guard let self = self else {
                    return
                }
                self.filterEmails(response.sensors)
                self.view.clearInput()
            }, failure: { [weak self] error in
                guard let self = self else {
                    return
                }
                self.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func filterEmails(_ sensors: [UserApiSharedResponse.Sensor]) {
        let oldCount = viewModel.sharedEmails.value?.count

        viewModel.sharedEmails.value = sensors.compactMap({
            if $0.sensor == self.ruuviTagId {
                return $0.sharedTo
            } else {
                return nil
            }
        })
        let newCount = viewModel.sharedEmails.value?.count
        if (newCount == 0 && oldCount != 0)
            || (newCount != 0 && oldCount == 0) {
            view.reloadTableView()
        } else {
            view.reloadSharedEmailsSection()
        }
    }
}
