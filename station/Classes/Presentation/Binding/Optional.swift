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

extension Optional where Wrapped == Int {
    var _bound: Int? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    public var bound: Int {
        get {
            return _bound ?? 0
        }
        set {
            _bound = newValue
        }
    }
}

extension Optional where Wrapped == String {
    var _bound: String? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    public var bound: String {
        get {
            return _bound ?? ""
        }
        set {
            _bound = newValue
        }
    }
}

extension Optional where Wrapped == Double {
    var _bound: Double? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
    public var bound: Double {
        get {
            return _bound ?? 0.0
        }
        set {
            _bound = newValue
        }
    }
}
