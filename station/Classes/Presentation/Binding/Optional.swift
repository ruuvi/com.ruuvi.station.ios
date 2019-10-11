import Foundation

public protocol OptionalType: ExpressibleByNilLiteral {
    associatedtype WrappedType
    var asOptional: WrappedType? { get }
}

extension Optional: OptionalType {
    public var asOptional: Wrapped? {
        return self
    }
}

extension Optional where Wrapped == Bool {
    var _bound: Bool? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    public var bound: Bool {
        get {
            return _bound ?? true
        }
        set {
            _bound = newValue
        }
    }
}
