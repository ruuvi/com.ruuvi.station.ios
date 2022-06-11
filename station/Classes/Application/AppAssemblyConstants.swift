//
//  AppAssemblyConstants.swift
//  station
//
//  Created by Iiro Alhonen on 07.12.21.
//  Copyright © 2021 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation

struct Networking: Codable {
    var OpenWeatherMapAPIKey: String
    var RuuviCloudURL: String
}

final class AppAssemblyConstants {
    static let networkingPath = Bundle.main.path(forResource: "Networking", ofType: "plist")!
    static let xml = FileManager.default.contents(atPath: networkingPath)!
    static let networkingPlist = try! PropertyListDecoder().decode(Networking.self, from: xml)

    static let openWeatherMapApiKey = networkingPlist.OpenWeatherMapAPIKey
    static let ruuviCloudUrl = networkingPlist.RuuviCloudURL
    static let simpleWidgetKindId = "ruuvi.simpleWidget"
}
