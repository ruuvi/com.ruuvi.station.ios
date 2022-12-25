import Foundation

protocol TagChartsViewModuleOutput: AnyObject {
    func tagChartSafeToClose(module: TagChartsViewModuleInput,
                             dismissParent: Bool)
}
