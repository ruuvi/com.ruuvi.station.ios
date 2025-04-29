import Foundation
import SwiftUI
import RuuviOntology
import DGCharts

// This class is used to represent the data for a sensor's single graph in the app.
// graphType is used to determine which type of graph to show (e.g. temperature, humidity, etc.)
struct SensorGraphEntity {
    let id = UUID()
    let ruuviTagId: String
    let graphType: MeasurementType
    var dataSet: [ChartDataSet]
    var graphData: LineChartData?
    var upperAlertValue: Double?
    var lowerAlertValue: Double?
    var unit: String
}
