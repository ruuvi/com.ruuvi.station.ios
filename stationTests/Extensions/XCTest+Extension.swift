//
//  XCTest+Extension.swift
//  stationTests
//
//  Created by Viik.ufa on 17.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import XCTest

extension XCTest {
    func expectToEventually(_ test: @autoclosure () -> Bool, timeout: TimeInterval = 1.0, message: String = "") {
        let runLoop = RunLoop.current
        let timeoutDate = Date(timeIntervalSinceNow: timeout)
        repeat {
            // 1
            if test() {
                return
            }
            // 2
            runLoop.run(until: Date(timeIntervalSinceNow: 0.01))
        } while Date().compare(timeoutDate) == .orderedAscending // 3
        // 4
        XCTFail(message)
    }
}
