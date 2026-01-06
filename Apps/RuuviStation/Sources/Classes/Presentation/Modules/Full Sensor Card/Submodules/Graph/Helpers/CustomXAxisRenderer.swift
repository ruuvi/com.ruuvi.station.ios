import DGCharts
import Foundation
import UIKit
import RuuviOntology

public final class CustomXAxisRenderer: XAxisRenderer {
    private var from: TimeInterval = 0
    private let extraTicks: Int64 = 2

    // Intervals in seconds - minimum is now 60 seconds (1 minute)
    let intervals: [TimeInterval] = [
        60,        // 1m
        120,       // 2m
        180,       // 3m
        300,       // 5m
        600,       // 10m
        900,       // 15m
        1800,      // 30m
        3600,      // 1h
        7200,      // 2h
        10800,     // 3h
        21600,     // 6h
        43200,     // 12h
        86400,     // 1d
        172800,    // 2d
        345600,    // 4d
        691200,    // 8d
    ]

    public convenience init(
        from time: Double,
        viewPortHandler: ViewPortHandler,
        axis: XAxis,
        transformer: Transformer?
    ) {
        self.init(viewPortHandler: viewPortHandler, axis: axis, transformer: transformer)
        from = time
    }

    override public func computeAxisValues(
        min: Double,
        max: Double
    ) {
        let range = abs(max - min)

        guard range > 0, range.isFinite else {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        // Preserve old behavior for very small datasets (< 1 minute)
        if range < 60 {
            axis.entries = [min]
            computeSize()
            return
        }

        let interval = selectInterval(
            min: min,
            max: max,
            range: range
        )

        // Epsilon to avoid off-by-one at exact boundaries due to floating rounding
        let eps = 1e-9

        // Absolute time range (epoch seconds)
        let tMin = from + min
        let tMax = from + max

        // Use integer multipliers to avoid drift
        var startMult = Int64(floor((tMin / interval) + eps)) - extraTicks
        var endMult   = Int64(ceil((tMax / interval) - eps)) + extraTicks

        // Handle behavior when alignment collapses (end < start)
        if endMult < startMult {
            let midPoint = (min + max) / 2
            let tMid = from + midPoint
            let midMult = Int64(floor((tMid / interval) + eps))
            startMult = midMult - extraTicks
            endMult = midMult + extraTicks
        }

        let numberOfPoints = Swift.max(1, Int(endMult - startMult) + 1)

        axis.entries = [Double](repeating: 0, count: numberOfPoints)

        for i in 0..<numberOfPoints {
            let mult = startMult + Int64(i)

            // Absolute tick time (epoch seconds aligned to interval)
            let absTick = Double(mult) * interval

            // Chart x is relative to `from`
            let value = absTick - from

            let date = Date(timeIntervalSince1970: absTick)

            // Preserve Android/iOS behavior: apply timezone offset only for intervals > 1h
            let localOffset = (interval > 3600)
                ? TimeZone.autoupdatingCurrent.secondsFromGMT(for: date)
                : 0

            axis.entries[i] = value - Double(localOffset)
        }

        computeSize()
    }

    private func selectInterval(
        min: Double,
        max: Double,
        range: Double
    ) -> TimeInterval {
        let rawInterval = range / Double(axis.labelCount)
        let baseInterval = closestInterval(to: rawInterval)

        guard let transformer = transformer,
              viewPortHandler.contentWidth > 0
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
                max: max,
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

    private func closestInterval(to rawInterval: Double) -> TimeInterval {
        if rawInterval < 60 { return 60 }
        return intervals.min(by: { abs($0 - rawInterval) < abs($1 - rawInterval) }) ?? 60
    }

    private func labelsFit(
        interval: TimeInterval,
        min: Double,
        max: Double,
        transformer: Transformer
    ) -> Bool {
        let eps = 1e-9
        let tMin = from + min
        let tMax = from + max

        var startMult = Int64(floor((tMin / interval) + eps)) - extraTicks
        var endMult = Int64(ceil((tMax / interval) - eps)) + extraTicks

        if endMult < startMult {
            let midPoint = (min + max) / 2
            let tMid = from + midPoint
            let midMult = Int64(floor((tMid / interval) + eps))
            startMult = midMult - extraTicks
            endMult = midMult + extraTicks
        }

        let valueToPixel = transformer.valueToPixelMatrix
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: axis.labelFont]
        var prevRight: CGFloat?

        for i in 0...Int(endMult - startMult) {
            let mult = startMult + Int64(i)
            let absTick = Double(mult) * interval
            let date = Date(timeIntervalSince1970: absTick)
            let localOffset = (interval > 3600)
                ? TimeZone.autoupdatingCurrent.secondsFromGMT(for: date)
                : 0
            let value = absTick - from - Double(localOffset)

            var position = CGPoint(x: value, y: 0)
            position = position.applying(valueToPixel)

            guard viewPortHandler.isInBoundsX(position.x) else { continue }

            let label = axis.valueFormatter?.stringForValue(value, axis: axis) ?? ""
            let labelSize = (label as NSString).size(withAttributes: labelAttrs)
            let rotatedWidth = rotatedLabelWidth(
                for: labelSize,
                angle: axis.labelRotationAngle
            )
            let halfWidth = rotatedWidth / 2
            let left = position.x - halfWidth
            let right = position.x + halfWidth

            if let prevRight = prevRight, left < prevRight - eps {
                return false
            }

            prevRight = right
        }

        return true
    }

    private func visibleTickCount(
        min: Double,
        max: Double,
        interval: TimeInterval
    ) -> Int {
        let eps = 1e-9
        let tMin = from + min
        let tMax = from + max

        let startMult = Int64(floor((tMin / interval) + eps)) - extraTicks
        let endMult = Int64(ceil((tMax / interval) - eps)) + extraTicks

        if endMult < startMult {
            return 0
        }

        var count = 0
        for i in 0...Int(endMult - startMult) {
            let mult = startMult + Int64(i)
            let absTick = Double(mult) * interval
            let date = Date(timeIntervalSince1970: absTick)
            let localOffset = (interval > 3600)
                ? TimeZone.autoupdatingCurrent.secondsFromGMT(for: date)
                : 0
            let value = absTick - from - Double(localOffset)
            if value + eps >= min && value - eps <= max {
                count += 1
            }
        }

        return count
    }

    private func rotatedLabelWidth(
        for size: CGSize,
        angle: CGFloat
    ) -> CGFloat {
        let radians = Double(angle) * Double.pi / 180.0
        let width = abs(Double(size.width) * cos(radians)) +
            abs(Double(size.height) * sin(radians))
        return CGFloat(width)
    }
}
