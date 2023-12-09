import Foundation

public enum MeasurementAccuracyType {
    case zero
    case one
    case two

    public var value: Int {
        switch self {
        case .zero:
            0
        case .one:
            1
        case .two:
            2
        }
    }

    public var displayValue: Double {
        switch self {
        case .zero:
            1
        case .one:
            0.1
        case .two:
            0.01
        }
    }
}
