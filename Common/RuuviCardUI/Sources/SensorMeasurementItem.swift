import Foundation

/// A single resolved measurement display item — value, unit, and label.
/// Shared between Watch and Widgets so both targets use identical data types.
public struct SensorMeasurementItem: Identifiable {
    public let id: String
    public let value: String
    public let unit: String
    public let label: String

    public init(id: String, value: String, unit: String, label: String) {
        self.id    = id
        self.value = value
        self.unit  = unit
        self.label = label
    }
}
