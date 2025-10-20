import DGCharts
import UIKit

class CustomYAxisRenderer: YAxisRenderer {
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
        guard min != CGFloat.greatestFiniteMagnitude && max != CGFloat.greatestFiniteMagnitude
        else {
            super.computeAxisValues(min: min, max: max)
            return
        }

        let labelCount = axis.labelCount
        let range = abs(max - min)

        if labelCount == 0 || range <= 0 {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        let interval = getClosestPredefinedInterval(range: range, labelCount: labelCount)

        var firstPoint = round(min / CGFloat(interval)) * CGFloat(interval)
        var lastPoint = round(max / CGFloat(interval)) * CGFloat(interval)

        if range < CGFloat(interval) {
            firstPoint = min
            lastPoint = firstPoint
        }

        let numberOfPoints = interval != 0.0 ? Int(
            round(abs(lastPoint - firstPoint) / CGFloat(interval))
        ) + 1 : 1

        axis.entries.removeAll(keepingCapacity: true)
        axis.entries.reserveCapacity(numberOfPoints)
        axis.entries = stride(
            from: firstPoint,
            to: firstPoint + CGFloat(numberOfPoints) * CGFloat(interval),
            by: CGFloat(interval)
        ).map { Double($0) }
    }

    private func getClosestPredefinedInterval(range: Double, labelCount: Int) -> Double {
        return intervals.min(
            by: { abs(range / $0 - Double(labelCount)) < abs(range / $1 - Double(labelCount)) }
        ) ?? 0
    }
}
