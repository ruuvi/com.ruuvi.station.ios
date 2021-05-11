import Foundation

protocol TagChartsModuleOutput: AnyObject {
    func tagCharts(module: TagChartsModuleInput, didScrollTo uuid: String)
    func tagChartsDidDeleteTag(module: TagChartsModuleInput)
}
