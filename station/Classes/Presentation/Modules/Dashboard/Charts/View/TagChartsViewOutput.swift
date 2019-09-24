import Foundation

protocol TagChartsViewOutput {
    func viewDidTriggerDashboard()
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidScroll(to index: Int)
}
