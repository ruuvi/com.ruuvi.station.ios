//
//  TagChartModuleInput.swift
//  station
//
//  Created by Viik.ufa on 21.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import UIKit

protocol TagChartModuleInput: class {
    func configure(for tagUUID: String, with type: MeasurementType)
    func startObserving()
    func stopObserving()
}
