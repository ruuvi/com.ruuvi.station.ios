import Foundation

protocol MenuViewOutput {
    var userIsAuthorized: Bool { get }
    var userEmail: String? { get }
    func viewWillAppear()
    func viewDidTapOnDimmingView()
    func viewDidSelectAddRuuviTag()
    func viewDidSelectAbout()
    func viewDidSelectWhatToMeasure()
    func viewDidSelectGetMoreSensors()
    // TODO: REMOVE THIS, NO LONGER SUPPORTED.
    func viewDidSelectGetRuuviGateway()
    func viewDidSelectSettings()
    func viewDidSelectFeedback()
    func viewDidSelectAccountCell()
}
