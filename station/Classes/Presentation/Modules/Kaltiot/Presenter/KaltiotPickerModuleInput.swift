//
//  KaltiotPickerModuleInput.swift
//  station
//
//  Created by Viik.ufa on 24.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation

protocol KaltiotPickerModuleInput: class {
    func configure(output: KaltiotPickerModuleOutput)
    func popViewController(animated: Bool)
}
