import CoreGraphics
import RuuviOntology

protocol CardsAlertsViewOutput: AnyObject {
    func viewDidLoad()
    func viewDidChangeAlertState(for type: AlertType, isOn: Bool)
    func viewDidChangeAlertLowerBound(for type: AlertType, lower: CGFloat)
    func viewDidChangeAlertUpperBound(for type: AlertType, upper: CGFloat)
    func viewDidChangeCloudConnectionAlertUnseenDuration(duration: Int)
    func viewDidChangeAlertDescription(for type: AlertType, description: String?)
}
