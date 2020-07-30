import Foundation

protocol TagChartModuleOutput: class {
    var dataSource: [RuuviMeasurement] { get }
    var lastMeasurement: RuuviMeasurement? { get }
}
