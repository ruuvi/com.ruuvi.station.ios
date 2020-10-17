import Foundation

protocol MenuViewOutput {
    var userIsAuthorized: Bool { get }
    func viewDidTapOnDimmingView()
    func viewDidSelectAddRuuviTag()
    func viewDidSelectAbout()
    func viewDidSelectGetMoreSensors()
    func viewDidSelectSettings()
    func viewDidSelectFeedback()
    func viewDidSelectAccountCell()
}
