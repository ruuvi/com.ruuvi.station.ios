import DGCharts
import Foundation
import UIKit

public final class CustomXAxisRenderer: XAxisRenderer {
    private var from: TimeInterval = 0
    var calendar = Calendar.autoupdatingCurrent

    // Cover the full retained history as well as zoomed views.
    private let intervals: [TimeInterval] = [
        60, 120, 180, 300, 600, 900, 1800,
        3600, 7200, 10800, 21600, 43200,
        86400, 172_800, 345_600, 691_200,
        1_382_400, 2_764_800, 5_529_600, 7_776_000, 11_059_200, 15_552_000,
        22_118_400, 31_536_000, 44_236_800, 63_072_000, 88_473_600,
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

    override public func computeAxisValues(min: Double, max: Double) {
        axis.entries = []
        axis.centeredEntries = []
        let range = max - min
        guard min.isFinite, max.isFinite, range.isFinite, range > 0 else { return }

        (axis.valueFormatter as? XAxisValueFormatter)?.visibleRange = range
        let targetInterval = range / Double(Swift.max(1, axis.labelCount - 1))
        let firstIndex = intervals.indices.min {
            abs(intervals[$0] - targetInterval) < abs(intervals[$1] - targetInterval)
        } ?? 0
        for interval in intervals[firstIndex...] {
            (axis.valueFormatter as? XAxisValueFormatter)?.tickInterval = interval
            let entries = ticks(min: min, max: max, interval: interval)
            if entries.count <= axis.labelCount, labelsFit(entries, min: min, range: range) {
                axis.entries = entries
                break
            }
        }

        // A deeply zoomed view may contain no minute boundary.
        if axis.entries.isEmpty, range < 60 {
            axis.entries = [min]
        }
        computeSize()
    }

    private func ticks(min: Double, max: Double, interval: TimeInterval) -> [Double] {
        let firstDate = Date(timeIntervalSince1970: from + min)
        let lastDate = Date(timeIntervalSince1970: from + max)
        var dates: [Date] = []

        if interval >= 86400 {
            let days = Int(interval / 86400)
            // A fixed local calendar anchor keeps ticks stable while panning.
            let anchor = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
            let distance = calendar.dateComponents([.day], from: anchor, to: firstDate).day ?? 0
            let aligned = Int(floor(Double(distance) / Double(days))) * days
            guard var date = calendar.date(byAdding: .day, value: aligned, to: anchor) else { return [] }
            while date <= lastDate {
                dates.append(date)
                guard let next = calendar.date(byAdding: .day, value: days, to: date), next > date else { break }
                date = next
            }
        } else if interval < 3600 {
            let anchor = calendar.startOfDay(for: firstDate).timeIntervalSince1970
            let firstTick = anchor + ceil((firstDate.timeIntervalSince1970 - anchor) / interval) * interval
            return stride(from: firstTick, through: lastDate.timeIntervalSince1970, by: interval).map { $0 - from }
        } else {
            // Align to local clock time, including time zones with fractional-hour offsets.
            // Restart at each local midnight so DST cannot shift the next day's grid.
            var day = calendar.startOfDay(for: firstDate)
            while day <= lastDate {
                for minute in stride(from: 0, to: 1440, by: Int(interval / 60)) {
                    if let date = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day) {
                        dates.append(date)
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
                day = next
            }
        }

        return Set(dates.map { $0.timeIntervalSince1970 - from })
            .filter { $0 >= min && $0 <= max }.sorted()
    }

    override public func drawLabel(
        context: CGContext,
        formattedLabel: String,
        x: CGFloat,
        y: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        constrainedTo size: CGSize,
        anchor: CGPoint,
        angleRadians: CGFloat
    ) {
        let labelSize = (formattedLabel as NSString).size(withAttributes: attributes)
        let width = abs(labelSize.width * cos(angleRadians)) + abs(labelSize.height * sin(angleRadians))
        let center = Swift.max(width / 2, Swift.min(x, viewPortHandler.chartWidth - width / 2))
        super.drawLabel(
            context: context,
            formattedLabel: formattedLabel,
            x: center,
            y: y,
            attributes: attributes,
            constrainedTo: size,
            anchor: anchor,
            angleRadians: angleRadians
        )
    }

    private func labelsFit(_ entries: [Double], min: Double, range: Double) -> Bool {
        guard viewPortHandler.contentWidth > 0 else { return true }
        let attributes: [NSAttributedString.Key: Any] = [.font: axis.labelFont]
        let angle = Double(axis.labelRotationAngle) * .pi / 180
        var previousRight: Double?
        for entry in entries {
            let label = axis.valueFormatter?.stringForValue(entry, axis: axis) ?? ""
            let size = (label as NSString).size(withAttributes: attributes)
            let width = abs(Double(size.width) * cos(angle)) + abs(Double(size.height) * sin(angle))
            let position = Double(viewPortHandler.contentLeft) +
                (entry - min) / range * Double(viewPortHandler.contentWidth)
            let center = Swift.max(width / 2, Swift.min(position, Double(viewPortHandler.chartWidth) - width / 2))
            if let previousRight, center - width / 2 < previousRight + 12 { return false }
            previousRight = center + width / 2
        }
        return true
    }
}
