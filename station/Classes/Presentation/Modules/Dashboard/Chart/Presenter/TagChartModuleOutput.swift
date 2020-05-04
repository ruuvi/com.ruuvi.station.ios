import Foundation

protocol TagChartModuleOutput: class {
    var dataSource: [RuuviMeasurement] { get }
}
