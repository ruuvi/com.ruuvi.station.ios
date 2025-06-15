import UIKit
import RuuviOntology
import SwiftUI
import Dragula

struct SensorSnapshot: Identifiable, DragulaItem {
    // MARK: – Identity (never changes)
    let id: String

    // MARK: – All changeable properties
    var displayName: String
    var background: UIImage?
    var indicators: [IndicatorModel]
    var meta: Meta

    // MARK: – Granular change tracking
    var displayVersion: Int = 0       // displayName changes
    var backgroundVersion: Int = 0       // background changes
    var timestampVersion: Int = 0     // Only for timestamp changes
    // TODO: Remove battery as it depends on indicator anyway
    var batteryVersion: Int = 0       // Only for battery changes
    var indicatorVersion: Int = 0     // Only for indicator changes
    var alertVersion: Int = 0         // Only for alert state changes
    var sourceVersion: Int = 0         // Only for alert state changes

    struct Meta {
        var timestamp: Date?
        var source: RuuviTagSensorRecordSource?
        var sourceIcon: Image?
        var batteryLow: Bool
        var alertState: AlertState?
    }

    // MARK: - Granular change detection keys
    var displayKey: String {
        "\(id)-d\(displayVersion)"
    }

    var backgroundVersionKey: String {
        "\(id)-d\(backgroundVersion)"
    }

    var timestampKey: String {
        "\(id)-t\(timestampVersion)"
    }

    var batteryKey: String {
        "\(id)-b\(batteryVersion)"
    }

    var indicatorKey: String {
        "\(id)-i\(indicatorVersion)"
    }

    var alertKey: String {
        "\(id)-a\(alertVersion)"
    }

    var sourceKey: String {
        "\(id)-a\(sourceVersion)"
    }
}

extension SensorSnapshot {
    /// Changes whenever *any* visible part of the card changes.
    var changeToken: String? {
        "\(id)-\(displayVersion)-\(backgroundVersion)-\(timestampVersion)-\(batteryVersion)-\(indicatorVersion)-\(alertVersion)-\(sourceVersion)"
    }
}

// MARK: - Minimal Equatable Implementation
extension SensorSnapshot: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        // Compare ID and all version numbers for granular change detection
        return lhs.id == rhs.id &&
               lhs.displayVersion == rhs.displayVersion &&
               lhs.backgroundVersion == rhs.backgroundVersion &&
               lhs.timestampVersion == rhs.timestampVersion &&
               lhs.batteryVersion == rhs.batteryVersion &&
               lhs.indicatorVersion == rhs.indicatorVersion &&
               lhs.alertVersion == rhs.alertVersion &&
               lhs.sourceVersion == rhs.sourceVersion
    }
}

// MARK: - IndicatorModel

struct IndicatorModel: Identifiable, Hashable {
    let id = UUID()
    let kind: Kind

    let title: String?
    var value: String
    var unit: String?

    var progress: Float?
    var maximumValue: Int?
    var tint: UIColor?
    var alertState: AlertState?

    var isProminent: Bool
}

extension IndicatorModel: Equatable {
    public static func == (lhs: IndicatorModel, rhs: IndicatorModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.kind == rhs.kind &&
               lhs.title == rhs.title &&
               lhs.value == rhs.value &&
               lhs.unit == rhs.unit &&
               lhs.progress == rhs.progress &&
               lhs.maximumValue == rhs.maximumValue &&
               lhs.tint == rhs.tint &&
               lhs.alertState == rhs.alertState &&
               lhs.isProminent == rhs.isProminent
    }
}


extension IndicatorModel {
    enum Kind: Hashable {
        case temperature, humidity, pressure, movement
        case measurementSequence, voltage, txPower, signalStrength
        case accelerationX, accelerationY, accelerationZ
        case co2, pm1, pm25, pm40, pm10, nox, voc, luminosity, soundAvg, soundPeak
        case aqi, aqiProminent
    }

    /// convenience ctor
    static func make(
        kind: Kind,
        title: String? = nil,
        value: String,
        unit: String? = nil,
        maximumValue: Int? = nil,
        progress: Float? = nil,
        tint: UIColor? = nil,
        alertState: AlertState? = nil,
        prominent: Bool = false
    ) -> IndicatorModel {
        .init(
            kind: kind,
            title: title,
            value: value,
            unit: unit,
            progress: progress,
            maximumValue: maximumValue,
            tint: tint,
            alertState: alertState,
            isProminent: prominent
        )
    }
}
