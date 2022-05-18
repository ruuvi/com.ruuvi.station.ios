import Foundation

protocol MenuViewOutput {
    var userIsAuthorized: Bool { get }
    var userEmail: String? { get }
    func viewDidLoad()
    func viewDidTapOnDimmingView()
    func viewDidSelectAddRuuviTag()
    func viewDidSelectAbout()
    func viewDidSelectGetMoreSensors()
    func viewDidSelectGetRuuviGateway()
    func viewDidSelectSettings()
    func viewDidSelectFeedback()
    func viewDidSelectAccountCell()
    func viewDidTapSyncButton()
}
