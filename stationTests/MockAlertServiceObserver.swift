//
//  MockAlertServiceObserver.swift
//  stationTests
//
//  Created by Viik.ufa on 15.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation
@testable import station

class MockAlertServiceObserver: AlertServiceObserver {
    var service: AlertService? = .none
    var isTriggered: Bool? = .none
    var uuid: String? = .none

    func alert(service: AlertService, isTriggered: Bool, for uuid: String) {
        self.service = service
        self.isTriggered = isTriggered
        self.uuid = uuid
    }
}
