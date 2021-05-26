import Foundation
import RuuviOntology

class ChartFilterOperation: Operation {
    private var array: [RuuviMeasurement]
    private var startDate: TimeInterval
    private var endDate: TimeInterval
    private var threshold: Int
    var sorted: [RuuviMeasurement] = []
    var type: MeasurementType
    override var isConcurrent: Bool {
        return true
    }
    init(array: [RuuviMeasurement],
         threshold: Int,
         type: MeasurementType,
         start: TimeInterval,
         end: TimeInterval) {
        self.array = array
        self.threshold = threshold
        self.type = type
        self.startDate = start
        self.endDate = end
    }
    override func main() {
        guard !isCancelled,
            array.count > threshold else {
            sorted = array
            return
        }
        if let first = array.first {
            sorted.append(first)
        }
        for item in array {
            guard !isCancelled else {
                cancel()
                return
            }
            if item.date.timeIntervalSince1970 > startDate,
                item.date.timeIntervalSince1970 < endDate {
                sorted.append(item)
            }
        }
        if let last = array.last {
            sorted.append(last)
        }
        guard !isCancelled else {
            cancel()
            return
        }
        sorted.sort(by: {$0.date < $1.date})
    }
}
