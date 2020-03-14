//
//  WPSData.swift
//  station
//
//  Created by Viik.ufa on 13.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. All rights reserved.
//

import Foundation

struct WPSData {
    var celsius: Double?
    var humidity: Double?
    var pressure: Double?

    var fahrenheit: Double? {
        return celsius?.fahrenheit
    }

    var kelvin: Double? {
        return celsius?.kelvin
    }
}
