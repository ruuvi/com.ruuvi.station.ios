import UIKit
import RuuviLocalization

/// Associates the shared snackbar with the sensor whose warning was tapped.
@MainActor
final class MeasurementWarningPresenter {
    var sensorID: String? { snackbar.isPresented ? presentedSensorID : nil }

    private var presentedSensorID: String?
    private let snackbar: SnackbarPresenter

    init(
        duration: TimeInterval = 3,
        animationDuration: TimeInterval = 0.25,
        notificationCenter: NotificationCenter = .default
    ) {
        snackbar = SnackbarPresenter(
            duration: duration, animationDuration: animationDuration, notificationCenter: notificationCenter
        )
    }

    init(snackbar: SnackbarPresenter) { self.snackbar = snackbar }

    @discardableResult
    func show(for sensorID: String, in view: UIView) -> Bool {
        guard self.sensorID != sensorID else { return false }
        if snackbar.restartDismissal(in: view) {
            presentedSensorID = sensorID
            return true
        }
        guard snackbar.show(
            message: RuuviLocalization.sensorMeasurementsOutdated,
            in: view, accessibilityIdentifier: "outdated-measurement-message"
        ) else { return false }
        presentedSensorID = sensorID
        return true
    }

    func dismiss(animated: Bool = true) {
        snackbar.dismiss(animated: animated)
    }

    func dismiss(for sensorID: String) {
        if self.sensorID == sensorID { dismiss() }
    }
}
