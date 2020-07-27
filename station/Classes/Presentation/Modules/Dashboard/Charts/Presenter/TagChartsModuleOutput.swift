import Foundation

protocol TagChartsModuleOutput: class {
    func tagCharts(module: TagChartsModuleInput, didScrollTo uuid: String)
    func tagChartsDidDeleteTag(module: TagChartsModuleInput)
}
