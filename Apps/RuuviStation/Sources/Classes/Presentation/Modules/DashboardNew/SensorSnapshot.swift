import UIKit
import RuuviOntology
import SwiftUI
import Dragula

struct SensorSnapshot: Identifiable, DragulaItem {
    // MARK: – Identity (never changes)
    let id: String

    // MARK: – All changeable properties
    let displayName: String
    var background: UIImage?
    let indicators: [IndicatorModel]
    let meta: Meta

    // MARK: – Granular change tracking
    var displayVersion: Int = 0       // displayName and background changes
    var timestampVersion: Int = 0     // Only for timestamp changes
    // TODO: Remove battery as it depends on indicator anyway
    var batteryVersion: Int = 0       // Only for battery changes
    var indicatorVersion: Int = 0     // Only for indicator changes
    var alertVersion: Int = 0         // Only for alert state changes
    var sourceVersion: Int = 0         // Only for alert state changes

    struct Meta {
        let updatedAt: String?
        let timestamp: Date?
        let source: RuuviTagSensorRecordSource?
        let sourceIcon: Image?
        let batteryLow: Bool
        let alertState: AlertState?
    }

    // MARK: - Granular change detection keys
    var displayKey: String {
        "\(id)-d\(displayVersion)"
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
        "\(id)-\(displayVersion)-\(timestampVersion)-\(batteryVersion)-\(indicatorVersion)-\(alertVersion)-\(sourceVersion)"
    }
}

// MARK: - Minimal Equatable Implementation
extension SensorSnapshot: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        // Compare ID and all version numbers for granular change detection
        return lhs.id == rhs.id &&
               lhs.displayVersion == rhs.displayVersion &&
               lhs.timestampVersion == rhs.timestampVersion &&
               lhs.batteryVersion == rhs.batteryVersion &&
               lhs.indicatorVersion == rhs.indicatorVersion &&
               lhs.alertVersion == rhs.alertVersion &&
               lhs.sourceVersion == rhs.sourceVersion
    }
}

/// Updated struct (matches the one in your last message but
///  *replaces* `isHighlighted` with a real `AlertState`)
struct IndicatorModel: Identifiable, Hashable {
    let id = UUID()
    let kind: Kind

    let title: String
    let value: String
    let unit: String?

    // extras
    let progress: Float?
    let tint: UIColor?
    let alertState: AlertState?

    // presentation flags
    let isProminent: Bool
}


// MARK: - IndicatorModel refresh
extension IndicatorModel {
    enum Kind: Hashable {
        case temperature, humidity, pressure, movement
        case co2, pm25, pm10, nox, voc, luminosity, sound
        case aqi
    }

    /// convenience ctor
    static func make(kind: Kind,
                     title: String,
                     value: String,
                     unit: String? = nil,
                     progress: Float? = nil,
                     tint: UIColor? = nil,
                     alertState: AlertState? = nil,
                     prominent: Bool = false) -> IndicatorModel {

        .init(kind: kind,
              title: title,
              value: value,
              unit: unit,
              progress: progress,
              tint: tint,
              alertState: alertState,
              isProminent: prominent)
    }
}
