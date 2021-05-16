import Foundation

protocol AdvancedViewOutput {
    func viewWillDisappear()
    func viewDidChangeStepperValue(for index: Int, newValue: Int)
    func viewDidChangeSwitchValue(for index: Int, newValue: Bool)
    func viewDidPress(at indexPath: IndexPath)
}
