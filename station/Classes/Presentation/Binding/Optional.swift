import Foundation

public protocol OptionalType: ExpressibleByNilLiteral {
    associatedtype WrappedType
    var asOptional: WrappedType? { get }
}

extension Optional: OptionalType {
    public var asOptional: Wrapped? {
        self
    }
}

extension Bool? {
    var _bound: Bool? {
        get {
            self
        }
        set {
            self = newValue
        }
    }

    public var bound: Bool {
        get {
            _bound ?? true
        }
        set {
            _bound = newValue
        }
    }
}

extension Int? {
    var _bound: Int? {
        get {
            self
        }
        set {
            self = newValue
        }
    }

    public var bound: Int {
        get {
            _bound ?? 0
        }
        set {
            _bound = newValue
        }
    }
}

extension String? {
    var _bound: String? {
        get {
            self
        }
        set {
            self = newValue
        }
    }

    public var bound: String {
        get {
            _bound ?? ""
        }
        set {
            _bound = newValue
        }
    }
}

extension Double? {
    var _bound: Double? {
        get {
            self
        }
        set {
            self = newValue
        }
    }

    public var bound: Double {
        get {
            _bound ?? 0.0
        }
        set {
            _bound = newValue
        }
    }
}
