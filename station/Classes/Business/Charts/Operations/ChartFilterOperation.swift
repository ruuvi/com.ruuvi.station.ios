//
//  ChartFilterOperation.swift
//  station
//
//  Created by Viik.ufa on 20.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

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
        sorted.append(contentsOf: array.prefix(2))
        for item in array {
            guard !isCancelled else {
                return
            }
            if item.tagUuid == uuid,
                item.date.timeIntervalSince1970 > startDate,
                item.date.timeIntervalSince1970 < endDate {
                sorted.append(item)
            }
        }
        sorted.append(contentsOf: array.suffix(2))
        guard !isCancelled else {
            return
        }
        sorted.sort(by: {$0.date < $1.date})
    }
}
