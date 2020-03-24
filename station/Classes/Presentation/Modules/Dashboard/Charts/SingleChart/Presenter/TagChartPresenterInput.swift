//
//  TagChartPresenterInput.swift
//  station
//
//  Created by Viik.ufa on 21.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation
import Charts

protocol TagChartPresenterInput: class {
    var chartData: LineChartData { get }
}
