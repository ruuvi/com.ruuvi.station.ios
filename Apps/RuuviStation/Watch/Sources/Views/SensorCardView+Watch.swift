import SwiftUI

// SensorCardView is defined in Common/RuuviCardUI/Sources/SensorCardView.swift
// and compiled directly into this target.
//
// This extension provides a Watch-specific convenience initialiser that takes a
// WatchSensor, resolves measurement items using the shared settings synced from
// the iPhone, and forwards to the shared dashboard-style card view.

extension SensorCardView {
    init(sensor: WatchSensor, appGroupDefaults: UserDefaults?) {
        self.init(
            displayName: sensor.displayName,
            formattedUpdatedAt: sensor.formattedUpdatedAt(),
            items: sensor.displayItems(appGroupDefaults: appGroupDefaults),
            style: .dashboardSimple
        )
    }
}
