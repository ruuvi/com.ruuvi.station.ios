import UIKit
import RuuviPresenters

class AlertPresenterImpl: AlertPresenter {
    func showAlert(_ viewModel: AlertViewModel) {
        let alert = UIAlertController(title: viewModel.title,
                                      message: viewModel.message,
                                      preferredStyle: viewModel.style)
        viewModel.actions.forEach({ alert.addAction($0) })
        let group = DispatchGroup()
        DispatchQueue.main.async {
            group.enter()
            let topViewController = UIApplication.shared.topViewController()
            var fireAfter: DispatchTimeInterval = .milliseconds(0)
            if topViewController is ActivityRuuviLogoViewController {
                fireAfter = .milliseconds(750)
            }
            group.leave()
            group.notify(queue: .main) {
                DispatchQueue.main.asyncAfter(deadline: .now() + fireAfter) {
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.error)
                    feedback.prepare()
                    UIApplication.shared.topViewController()?.present(alert, animated: true)
                }
            }
        }
    }
}
