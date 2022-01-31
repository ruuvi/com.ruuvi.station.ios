//
//  String+Email.swift
//  station
//
//  Created by iPriyo on 28/1/22.
//  Copyright © 2022 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation
extension String {
    /// This method extracts email address from a given string.
    func email() -> String? {
        if let regex = try? NSRegularExpression(pattern: "\\b\\S*@\\S*\\.\\S*\\b", options: .caseInsensitive) {
            let string = self as NSString
            let match = regex.matches(in: self, options: [], range: NSRange(location: 0, length: string.length)).map {
                string.substring(with: $0.range).lowercased()
            }
            return match.first
        }
        return self
    }
}
