//
//  MockCalibrationService.swift
//  stationTests
//
//  Created by Viik.ufa on 14.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. All rights reserved.
//

import Foundation
import Future
@testable import station

class MockCalibrationService: CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {

        return .init(value: true)
    }

    func cleanHumidityCalibration(for ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        return .init(value: true)
    }

    func humidityOffset(for uuid: String) -> (Double, Date?) {
        return (0, Date())
    }

    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        return .init(value: false)
    }

}
