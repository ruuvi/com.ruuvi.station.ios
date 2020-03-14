//
//  MockRuuviTag.swift
//  stationTests
//
//  Created by Viik.ufa on 14.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. All rights reserved.
//

import Foundation
@testable import station

struct MockRuuviTag: RuuviTagProtocol {
    var uuid: String
    var version: Int = 5
    var isConnectable: Bool = true
    var isConnected: Bool = true
    var voltage: Double?
    var accelerationX: Double?
    var accelerationY: Double?
    var accelerationZ: Double?
    var movementCounter: Int?
    var measurementSequenceNumber: Int?
    var txPower: Int?
    var rssi: Int?
    var humidity: Double?
    var pressure: Double?
    var inHg: Double?
    var mmHg: Double?
    var celsius: Double?
    var mac: String?
    var fahrenheit: Double?
    var kelvin: Double?
}
