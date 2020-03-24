//
//  TagChartAssembly.swift
//  station
//
//  Created by Viik.ufa on 21.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import UIKit

class TagChartConfigurator {
    func configure(view: TagChartView) {
        let r = AppAssembly.shared.assembler.resolver
        let presenter = TagChartPresenter()
        view.presenter = presenter
        view.delegate = presenter
        presenter.view = view
        view.data = presenter.chartData
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.settings = r.resolve(Settings.self)
    }
}
