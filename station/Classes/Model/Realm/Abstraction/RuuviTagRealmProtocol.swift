//
//  RuuviTagRealm.swift
//  station
//
//  Created by Viik.ufa on 14.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. All rights reserved.
//

import Foundation
import RealmSwift

protocol RuuviTagRealmProtocol: Object {
    var uuid: String { get set }
    var name: String { get set }
    var mac: String? { get set }
    var version: Int { get set }
    var isConnectable: Bool { get set }
    var humidityOffset: Double { get set }
    var humidityOffsetDate: Date? { get set }
    var data: LinkingObjects<RuuviTagDataRealm> { get }
    init(ruuviTag: RuuviTagProtocol, name: String)
}
