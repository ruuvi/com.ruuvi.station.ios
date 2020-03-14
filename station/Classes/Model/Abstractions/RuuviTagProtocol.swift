//
//  RuuviTagProtocol.swift
//  station
//
//  Created by Viik.ufa on 14.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. All rights reserved.
//

import Foundation
import BTKit

protocol RuuviTagProtocol {
    var voltage: Double? { get }
    var accelerationX: Double? { get }
    var accelerationY: Double? { get }
    var accelerationZ: Double? { get }
    var movementCounter: Int? { get }
    var measurementSequenceNumber: Int? { get }
    var txPower: Int? { get }
    var uuid: String { get }
    var rssi: Int? { get }
    var isConnectable: Bool { get }
    var version: Int { get }
    var humidity: Double? { get }
    var pressure: Double? { get }
    var inHg: Double? { get }
    var mmHg: Double? { get }
    var celsius: Double? { get }
    var mac: String? { get }
    var fahrenheit: Double? { get }
    var kelvin: Double? { get }
    var isConnected: Bool { get }
}
extension RuuviTag: RuuviTagProtocol {}
