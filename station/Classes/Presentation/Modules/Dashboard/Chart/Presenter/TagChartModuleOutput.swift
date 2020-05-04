import Foundation

protocol TagChartModuleOutput: class {
    var dataSource: Observable<[RuuviMeasurement]?> { get }
}
