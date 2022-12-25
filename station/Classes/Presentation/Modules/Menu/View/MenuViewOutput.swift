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
    func viewDidSelectSettings()
    func viewDidSelectFeedback()
    func viewDidSelectAccountCell()
}
