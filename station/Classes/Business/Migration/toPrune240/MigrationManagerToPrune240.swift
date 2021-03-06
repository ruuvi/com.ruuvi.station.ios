//
//  MigrationManagerToPrune240.swift
//  station
//
//  Created by Rinat Enikeev on 06.03.2021.
//  Copyright © 2021 Ruuvi Innovations Oy. BSD-3-Clause.
//

import Foundation

final class MigrationManagerToPrune240: MigrationManager {
    var settings: Settings!

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.dataPruningOffsetHours = 240
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToPrune240.migrated"
}
