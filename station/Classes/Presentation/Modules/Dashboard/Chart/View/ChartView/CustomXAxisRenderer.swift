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

        let offset = TimeZone.current.secondsFromGMT()
        let timeZoneOffset = (interval > 10800) ? offset : 0

        // swiftlint:disable line_length
        var firstPoint = ((from + min).toLong() / interval) * interval - from.toLong() - Int64(timeZoneOffset) - 2 * interval + (timeZoneOffset == 0 ? 0 : 3600)
        var lastPoint =  ((from + max).toLong() / interval) * interval - from.toLong() - Int64(timeZoneOffset) + 2 * interval + (timeZoneOffset == 0 ? 0 : 3600)
        // swiftlint:enable line_length

        if range.toLong() < interval {
            firstPoint = Int64(min)
            lastPoint = firstPoint
        }
        var numberOfPoints = 0
        if interval != 0 && lastPoint != firstPoint {
            stride(from: firstPoint, through: lastPoint, by: Int(interval)).forEach { _ in numberOfPoints += 1 }
        } else {
            numberOfPoints = 1
        }

        axis.entries.removeAll(keepingCapacity: true)
        axis.entries.reserveCapacity(numberOfPoints)

        let values = stride(from: firstPoint, to: lastPoint, by: Int(interval)).map({ Double($0) })
        axis.entries.append(contentsOf: values)

        computeSize()
    }

    private func getClosestPredefinedInterval(from rawInterval: Double) -> Int64 {
        // swiftlint:disable:next line_length
        let closest = intervals().enumerated().min(by: { abs($0.1 - rawInterval.toLong()) < abs($1.1 - rawInterval.toLong())})
        return closest?.element ?? 30
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
