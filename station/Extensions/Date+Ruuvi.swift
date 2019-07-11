//
//  Date+Ruuvi.swift
//  station
//
//  Created by Rinat Enikeev on 7/10/19.
//  Copyright © 2019 Ruuvi Innovations Oy. All rights reserved.
//

import Foundation

extension Date {
    var ruuviAgo: String {
        let elapsed = Int(Date().timeIntervalSince(self))
        var output = "Updated "
        // show date if the tag has not been seen for 24h
        if elapsed >= 24 * 60 * 60 {
            let df = DateFormatter()
            df.dateFormat = "EEE MMM dd HH:mm:ss ZZZZ yyyy"
            output += df.string(from: self)
        } else {
            let seconds = elapsed % 60
            let minutes = (elapsed / 60) % 60
            let hours   = (elapsed / (60*60)) % 24
            if hours > 0 {
                output += String(hours) + " h "
            }
            if minutes > 0 {
                output += String(minutes) + " min "
            }
            output += String(seconds) + " s ago"
        }
        return output
    }
}
