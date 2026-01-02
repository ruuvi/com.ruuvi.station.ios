import DGCharts
import UIKit

final class CustomYAxisRenderer: YAxisRenderer {
    private let intervals = [
        0.01,
        0.02,
        0.05,
        0.1,
        0.2,
        0.5,
        1.0,
        2.0,
        5.0,
        10.0,
        20.0,
        25.0,
        50.0,
        100.0,
        200.0,
        250.0,
        500.0,
        1000.0,
        2000.0,
        2500.0,
        5000.0,
        10000.0,
        20000.0,
        25000.0,
        50000.0,
        100_000.0,
        200_000.0,
        250_000.0,
        500_000.0,
        1_000_000.0,
    ]

    override func computeAxisValues(min: Double, max: Double) {
        guard min != Double.greatestFiniteMagnitude, max != Double.greatestFiniteMagnitude else {
            super.computeAxisValues(min: min, max: max)
            return
        }

        let labelCount = axis.labelCount
        let range = abs(max - min)

        guard labelCount != 0, range > 0, range.isFinite else {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        let interval = getClosestPredefinedInterval(range: range, labelCount: labelCount)

        if range < interval {
            axis.entries = [min]
            return
        }

        let eps = 1e-12

        let firstPoint = Darwin.floor((min / interval) + eps) * interval
        let lastPoint  = Darwin.ceil((max / interval) - eps) * interval

        let span = lastPoint - firstPoint
        let numberOfPoints = Swift.max(1, Int(Darwin.floor((span / interval) + eps)) + 1)

        axis.entries = (0..<numberOfPoints).map { i in
            firstPoint + Double(i) * interval
        }
    }

    private func getClosestPredefinedInterval(range: Double, labelCount: Int) -> Double {
        intervals.min(by: { abs(range / $0 - Double(labelCount)) < abs(range / $1 - Double(labelCount)) }) ?? 0
    }
}
