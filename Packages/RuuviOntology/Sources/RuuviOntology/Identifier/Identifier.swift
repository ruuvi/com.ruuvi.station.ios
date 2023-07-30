import Foundation

public protocol Identifier {
    var value: String { get }
}

public protocol LocalIdentifier: Identifier {
}

public protocol MACIdentifier: Identifier {
    var mac: String { get }
}

public struct MACIdentifierStruct: MACIdentifier {
    public var value: String
    public var mac: String {
        return value
    }

    public init(
        value: String
    ) {
        self.value = value
    }
}

public struct AnyMACIdentifier: MACIdentifier, Equatable, Hashable {
    var object: MACIdentifier

    public var value: String {
        return object.value
    }
    public var mac: String {
        return object.value
    }

    public static func == (lhs: AnyMACIdentifier, rhs: AnyMACIdentifier) -> Bool {
        return lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

public struct LocalIdentifierStruct: LocalIdentifier {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

public struct AnyLocalIdentifier: LocalIdentifier, Equatable, Hashable {
    var object: LocalIdentifier

    public var value: String {
        return object.value
    }

    public static func == (lhs: AnyLocalIdentifier, rhs: AnyLocalIdentifier) -> Bool {
        return lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension String {
    public var luid: LocalIdentifier {
        return LocalIdentifierStruct(value: self).any
    }

    public var mac: MACIdentifier {
        return MACIdentifierStruct(value: self).any
    }
}

extension Optional where Wrapped == String {
    public var luid: LocalIdentifier? {
        guard let self = self else {
            return nil
        }
        return LocalIdentifierStruct(value: self).any
    }

    public var mac: MACIdentifier? {
        guard let self = self else {
            return nil
        }
        return MACIdentifierStruct(value: self).any
    }
}

extension LocalIdentifier {
    public var any: AnyLocalIdentifier {
        return AnyLocalIdentifier(object: self)
    }
}

extension MACIdentifier {
    public var any: AnyMACIdentifier {
        return AnyMACIdentifier(object: self)
    }
}
