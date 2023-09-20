import Foundation
import RuuviOntology

protocol TagChartsViewModuleOutput: AnyObject {
    func tagChartSafeToClose(module: TagChartsViewModuleInput,
                             dismissParent: Bool)
    func tagChartSafeToSwipe(
        to ruuviTag: AnyRuuviTagSensor, module: TagChartsViewModuleInput
    )
}
