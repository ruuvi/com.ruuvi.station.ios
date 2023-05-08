import Foundation
import Charts
import RuuviOntology

public class CustomXAxisRenderer: XAxisRenderer {

    private var from: Double = 0

    convenience init(from time: Double, viewPortHandler: ViewPortHandler, axis: XAxis, transformer: Transformer?) {
        self.init(viewPortHandler: viewPortHandler, axis: axis, transformer: transformer)
        self.from = time
    }

    public override func computeAxisValues(min: Double,
                                           max: Double) {
        let labelCount = axis.labelCount
        let range = abs(max - min)

        guard
            labelCount != 0,
            range > 0,
            range.isFinite
            else
        {
            axis.entries = []
            axis.centeredEntries = []
            return
        }

        let rawInterval = range / Double(labelCount)
        let interval = getClosestPredefinedInterval(from: rawInterval)

        var firstPoint = ((from + min).toLong() / interval) * interval - from.toLong() - 2 * interval
        var lastPoint = ((from + max).toLong() / interval) * interval - from.toLong() + 2 * interval

        if range.toLong() < interval {
            firstPoint = Int64(min)
            lastPoint = firstPoint
        }

        var numberOfPoints = 0
        if lastPoint != firstPoint {
            numberOfPoints = Int((lastPoint - firstPoint) / interval) + 1
        } else {
            numberOfPoints = 1
        }

        axis.entries.removeAll(keepingCapacity: true)
        axis.entries.reserveCapacity(numberOfPoints)
        axis.entries = [Double](repeating: 0, count: numberOfPoints)

        for i in 0..<numberOfPoints {
            let value = firstPoint + Int64(i) * interval
            let date = Date(timeIntervalSince1970: from + Double(value))
            let localOffset = (interval > 3600) ? TimeZone.current.secondsFromGMT(for: date) : 0
            axis.entries[i] = Double(value) - TimeInterval(localOffset)
        }

        computeSize()
    }

    private func getClosestPredefinedInterval(from rawInterval: Double) -> Int64 {
        return intervals().min(by: {
            abs($0 - Int64(rawInterval)) < abs($1 - Int64(rawInterval))
        }) ?? 0
    }

    private func intervals() -> [Int64] {
        let intervals: [Int64] = [
            60,      // 1m
            120,     // 2m
            180,     // 3m
            300,     // 5m
            600,     // 10m
            900,     // 15m
            1800,    // 30m
            3600,    // 1h
            7200,    // 2h
            10800,   // 3h
            21600,   // 6h
            43200,   // 12h
            86400,   // 1d
            172800   // 2d
        ]
        return intervals
    }

}
extension Double {
    func toLong() -> Int64 {
        return Int64(self)
    }
}
