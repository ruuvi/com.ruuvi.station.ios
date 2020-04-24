//
//  KaltiotTableInitializer.swift
//  station
//
//  Created by Viik.ufa on 24.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import UIKit

class KaltiotTableInitializer: NSObject {
    @IBOutlet weak var viewController: KaltiotPickerTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        KaltiotPickerTableConfigurator().configure(view: viewController)
    }
}
