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

        let range = abs(max - min)

        guard range > 0, range.isFinite else {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        let interval = selectInterval(
            min: min,
            max: max,
            range: range
        )

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

    private func selectInterval(
        min: Double,
        max: Double,
        range: Double
    ) -> Double {
        let baseInterval = getClosestPredefinedInterval(
            range: range,
            labelCount: axis.labelCount
        )

        guard let transformer = transformer,
              viewPortHandler.contentHeight > 0
        else {
            return baseInterval
        }

        if visibleTickCount(
            min: min,
            max: max,
            interval: baseInterval
        ) >= axis.labelCount {
            return baseInterval
        }

        guard let baseIndex = intervals.firstIndex(of: baseInterval) else {
            return baseInterval
        }

        for i in stride(from: baseIndex - 1, through: 0, by: -1) {
            let candidate = intervals[i]

            if !labelsFit(
                interval: candidate,
                min: min,
                transformer: transformer
            ) {
                break
            }

            if visibleTickCount(
                min: min,
                max: max,
                interval: candidate
            ) >= axis.labelCount {
                return candidate
            }
        }

        return baseInterval
    }

    private func labelsFit(
        interval: Double,
        min: Double,
        transformer: Transformer
    ) -> Bool {
        let labelHeight = axis.labelFont.lineHeight
        let p1 = transformer.pixelForValues(x: 0, y: min)
        let p2 = transformer.pixelForValues(x: 0, y: min + interval)
        let spacing = abs(p2.y - p1.y)

        return spacing >= labelHeight
    }

    private func visibleTickCount(
        min: Double,
        max: Double,
        interval: Double
    ) -> Int {
        let eps = 1e-12
        let firstPoint = Darwin.floor((min / interval) + eps) * interval
        let lastPoint = Darwin.ceil((max / interval) - eps) * interval

        let span = lastPoint - firstPoint
        if span < 0 {
            return 0
        }

        return Swift.max(1, Int(Darwin.floor((span / interval) + eps)) + 1)
    }

    private func getClosestPredefinedInterval(range: Double, labelCount: Int) -> Double {
        intervals.min(by: { abs(range / $0 - Double(labelCount)) < abs(range / $1 - Double(labelCount)) }) ?? 0
    }
}
