import DGCharts
import Foundation
import RuuviOntology

public class CustomXAxisRenderer: XAxisRenderer {
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

    convenience init(
        from time: Double,
        viewPortHandler: ViewPortHandler,
        axis: XAxis,
        transformer: Transformer?
    ) {
        self.init(
            viewPortHandler: viewPortHandler,
            axis: axis,
            transformer: transformer
        )
        from = time
    }

    override public func computeAxisValues(
        min: Double,
        max: Double
    ) {
        let labelCount = axis.labelCount
        let range = abs(max - min)

        guard
            labelCount != 0,
            range > 0,
            range.isFinite
        else {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        // Calculate raw interval
        let rawInterval = range / Double(labelCount)

        // Get appropriate interval - enforce minimum 60s
        let interval = getClosestPredefinedInterval(from: rawInterval)

        // Special handling for very small datasets (e.g., single point)
        if range < 60 { // Less than a minute
            // For a single data point or very small range, just show one label at that point
            axis.entries = [min]
            computeSize()
            return
        }

        // Align first and last points to minute boundaries
        // Round to nearest minute boundary based on interval
        var firstPoint = floor((from + min) / interval) * interval - from
        var lastPoint = ceil((from + max) / interval) * interval - from

        // Ensure they're within the data range
        if firstPoint < min {
            firstPoint += interval
        }

        if lastPoint > max {
            lastPoint -= interval
        }

        // Handle case where range is smaller than interval
        if lastPoint < firstPoint {
            // Just use the midpoint
            let midPoint = (min + max) / 2
            firstPoint = floor((from + midPoint) / interval) * interval - from
            lastPoint = firstPoint
        }

        // Calculate number of points
        var numberOfPoints = 0
        if lastPoint >= firstPoint {
            for _ in stride(from: firstPoint, through: lastPoint, by: interval) {
                numberOfPoints += 1
            }
        }

        // Ensure at least one point
        if numberOfPoints == 0 {
            numberOfPoints = 1
            lastPoint = firstPoint
        }

        axis.entries.removeAll(keepingCapacity: true)
        axis.entries.reserveCapacity(numberOfPoints)
        axis.entries = [Double](repeating: 0, count: numberOfPoints)

        var i = 0
        for value in stride(from: firstPoint, through: lastPoint, by: interval) {
            guard i < numberOfPoints else { break }

            let date = Date(timeIntervalSince1970: from + value)

            // Apply timezone offset only for larger intervals (>= 1h)
            let localOffset = (interval >= 3600)
                ? TimeZone.autoupdatingCurrent.secondsFromGMT(for: date)
                : 0

            axis.entries[i] = value - Double(localOffset)
            i += 1
        }

        computeSize()
    }

    private func getClosestPredefinedInterval(from rawInterval: Double) -> TimeInterval {
        // Enforce minimum interval of 60 seconds (1 minute)
        if rawInterval < 60 {
            return 60
        }

        return intervals.min(by: {
            abs($0 - rawInterval) < abs($1 - rawInterval)
        }) ?? 60
    }
}
