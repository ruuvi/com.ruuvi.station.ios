//
//  KaltiotPickerTableConfigurator.swift
//  station
//
//  Created by Viik.ufa on 24.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation

class KaltiotPickerTableConfigurator {
    func configure(view: KaltiotPickerTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = KaltiotPickerRouter()
        router.transitionHandler = view

        let presenter = KaltiotPickerPresenter()
        presenter.view = view
        presenter.router = router
        presenter.keychainService = r.resolve(KeychainService.self)

        view.output = presenter
    }
}
