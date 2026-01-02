import DGCharts
import Foundation
import RuuviOntology

public final class CustomXAxisRenderer: XAxisRenderer {
    private var from: TimeInterval = 0

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
        let labelCount = axis.labelCount
        let range = abs(max - min)

        guard labelCount != 0, range > 0, range.isFinite else {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        let rawInterval = range / Double(labelCount)
        let interval = getClosestPredefinedInterval(from: rawInterval)

        // Preserve old behavior for very small datasets (< 1 minute)
        if range < 60 {
            axis.entries = [min]
            computeSize()
            return
        }

        // Epsilon to avoid off-by-one at exact boundaries due to floating rounding
        let eps = 1e-9

        // Absolute time range (epoch seconds)
        let tMin = from + min
        let tMax = from + max

        // Match Android: pad by 2 ticks on both ends
        let extraTicks: Int64 = 2

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

    private func getClosestPredefinedInterval(from rawInterval: Double) -> TimeInterval {
        if rawInterval < 60 { return 60 }
        return intervals.min(by: { abs($0 - rawInterval) < abs($1 - rawInterval) }) ?? 60
    }
}
