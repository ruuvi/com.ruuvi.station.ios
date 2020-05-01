import Foundation

class ChartFilterOperation: Operation {
    private var uuid: String
    private var array: [RuuviMeasurement]
    private var startDate: TimeInterval
    private var endDate: TimeInterval
    var sorted: [RuuviMeasurement] = []
    var type: MeasurementType
    override var isConcurrent: Bool {
        return true
    }
    init(uuid: String,
         array: [RuuviMeasurement],
         type: MeasurementType,
         start: TimeInterval,
         end: TimeInterval) {
        self.uuid = uuid
        self.array = array
        self.type = type
        self.startDate = start
        self.endDate = end
    }
    override func main() {
        guard !isCancelled,
            array.count > 100 else {
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
            if item.ruuviTagId == uuid,
                item.date.timeIntervalSince1970 > startDate,
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
