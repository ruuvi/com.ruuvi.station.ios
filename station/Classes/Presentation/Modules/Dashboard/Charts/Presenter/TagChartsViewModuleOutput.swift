import Foundation

protocol TagChartsViewModuleOutput: AnyObject {
    func tagCharts(module: TagChartsViewModuleInput, didScrollTo uuid: String)
    func tagChartsDidDeleteTag(module: TagChartsViewModuleInput)
}
