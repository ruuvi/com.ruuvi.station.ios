import Foundation

protocol RuuviTagViewOutput {
    func viewDidTapOnDimmingView()
    func viewDidTapOnView()
    func viewDidSave(name: String)
}
