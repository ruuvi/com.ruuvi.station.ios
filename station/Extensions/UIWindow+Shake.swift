//
//  UIWindow+Shake.swift
//  station
//
//  Created by Viik.ufa on 20.04.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import UIKit
#if DEVELOPMENT
import FLEX

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            FLEXManager.shared.showExplorer()
        }
    }
}
#endif
