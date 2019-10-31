import Foundation

protocol TagActionsViewOutput {
    func viewDidLoad()
    func viewDidAppear()
    func viewDidTapOnDimmingView()
    func viewDidAskToClear()
    func viewDidAskToSync()
    func viewDidAskToExport()
    func viewDidConfirmToSync()
    func viewDidConfirmToClear()
    func viewDidAskToExportTemperature()
    func viewDidAskToExportHumidity()
    func viewDidAskToExportPressure()
}
