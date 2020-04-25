//
//  WhereOSData.swift
//  station
//
//  Created by Viik.ufa on 25.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation

struct WhereOSData: Codable {
    var rssi: Int
    var rssiMax: Int
    var rssiMin: Int
    var data: String
    var coordinates: String
    var time: Date
    var id: String
    var gwmac: String
}
