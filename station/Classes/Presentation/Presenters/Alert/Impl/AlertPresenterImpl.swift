import RuuviPresenters
import UIKit

class AlertPresenterImpl: AlertPresenter {
    func showAlert(_ viewModel: AlertViewModel) {
        let alert = UIAlertController(
            title: viewModel.title,
            message: viewModel.message,
            preferredStyle: viewModel.style
        )
        viewModel.actions.forEach { alert.addAction($0) }
        DispatchQueue.main.async {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
            feedback.prepare()
            UIApplication.shared.topViewController()?.present(alert, animated: true)
        }
    }
}
