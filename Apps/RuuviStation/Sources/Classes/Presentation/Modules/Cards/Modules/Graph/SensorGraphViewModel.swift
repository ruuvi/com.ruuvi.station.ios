import Foundation
import RuuviOntology
import RuuviService
import DGCharts
import Combine
import SwiftUI

class SensorGraphViewModel: ObservableObject, Identifiable {
    @Published var graphEntity: SensorGraphEntity
    @Published var graphTitle: String
    @Published var unit: String

    var id: String { "\(graphEntity.ruuviTagId)_\(graphEntity.graphType.rawValue)" }
    weak var parentViewModel: SensorGraphContainerViewModel!

    init(graphEntity: SensorGraphEntity, parentViewModel: SensorGraphContainerViewModel) {
        self.graphEntity = graphEntity
        self.parentViewModel = parentViewModel
        self.graphTitle = graphEntity.graphType.rawValue
        self.unit = graphEntity.unit
    }

    func updateChartData(with newData: LineChartData) {
        graphEntity.graphData = newData
        objectWillChange.send()
    }

    func updateDataSet(with dataSet: [LineChartDataSet]) {
        graphEntity.dataSet = dataSet
        objectWillChange.send()
    }
}
