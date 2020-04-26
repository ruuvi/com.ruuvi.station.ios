//
//  KaltiotPickerPresenter.swift
//  station
//
//  Created by Viik.ufa on 24.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation

class KaltiotPickerPresenter {
    weak var view: KaltiotPickerViewInput!
    var output: KaltiotPickerModuleOutput!
    var router: KaltiotPickerRouterInput!
    var keychainService: KeychainService!
}
extension KaltiotPickerPresenter: KaltiotPickerViewOutput {
    func viewDidLoad() {
    }
}
extension KaltiotPickerPresenter: KaltiotPickerModuleInput {
    func configure(output: KaltiotPickerModuleOutput) {
        self.output = output
        #warning("dont forget remove this")
        keychainService.kaltiotApiKey = nil
    }

    func popViewController(animated: Bool) {
        router.popViewController(animated: animated)
    }
}
