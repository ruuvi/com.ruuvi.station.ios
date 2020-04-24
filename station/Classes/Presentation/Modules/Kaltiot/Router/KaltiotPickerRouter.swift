//
//  KaltiotPickerRouter.swift
//  station
//
//  Created by Viik.ufa on 24.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import UIKit

class KaltiotPickerRouter: KaltiotPickerRouterInput {
    weak var transitionHandler: UIViewController!

    func popViewController(animated: Bool) {
        transitionHandler.navigationController?.popViewController(animated: animated)
    }
}
