import Foundation

public enum MeasurementAccuracyType {
    case zero
    case one
    case two

    public var value: Int {
        switch self {
        case .zero:
            return 0
        case .one:
            return 1
        case .two:
            return 2
        }
    }

    public var displayValue: Double {
        switch self {
        case .zero:
            return 1
        case .one:
            return 0.1
        case .two:
            return 0.01
        }
    }
}
