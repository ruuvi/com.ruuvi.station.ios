//
//  KaltiotPickerModuleOutput.swift
//  station
//
//  Created by Viik.ufa on 24.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

protocol KaltiotPickerModuleOutput: class {
    func kaltiotPicker(module: KaltiotPickerModuleInput, didPick tagUuid: String)
}
