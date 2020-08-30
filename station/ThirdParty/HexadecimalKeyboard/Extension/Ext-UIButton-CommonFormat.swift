//
//  Ext-UIButton-CommonFormat.swift
//  KeyboardCustomAppOnly
//
//  Created by Marcy Vernon on 7/12/20.
//

import UIKit

// MARK: - Format Buttons
extension UIButton {
    func commonFormat() {
        self.titleLabel?.font = .preferredFont(forTextStyle: .title2 )
        if #available(iOS 13.0, *) {
            self.setTitleColor(.label, for: .normal)
        } else {
            // Fallback on earlier versions
        }
        self.layer.cornerRadius = 5
        self.accessibilityTraits = [.keyboardKey]
        self.shadow()
    }

    func shadow(_ radius: CGFloat = 1) {
        self.layer.shadowColor   = UIColor.black.cgColor
        self.layer.shadowOpacity = 1.0
        self.layer.shadowOffset  = CGSize(width: 0.0, height: 1.0)
        self.layer.shadowRadius  = radius
    }
}
