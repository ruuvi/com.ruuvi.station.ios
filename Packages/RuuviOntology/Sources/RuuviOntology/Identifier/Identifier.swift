import Foundation

public protocol Identifier {
    var value: String { get }
}

public protocol LocalIdentifier: Identifier {}

public protocol MACIdentifier: Identifier {
    var mac: String { get }
}

public struct MACIdentifierStruct: MACIdentifier {
    public var value: String
    public var mac: String {
        value
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
        object.value
    }

    public var mac: String {
        object.value
    }

    public static func == (lhs: AnyMACIdentifier, rhs: AnyMACIdentifier) -> Bool {
        lhs.value == rhs.value
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
        object.value
    }

    public static func == (lhs: AnyLocalIdentifier, rhs: AnyLocalIdentifier) -> Bool {
        lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

public extension String {
    var luid: LocalIdentifier {
        LocalIdentifierStruct(value: self).any
    }

    var mac: MACIdentifier {
        MACIdentifierStruct(value: self).any
    }
}

public extension String? {
    var luid: LocalIdentifier? {
        guard let self else {
            return nil
        }
        return LocalIdentifierStruct(value: self).any
    }

    var mac: MACIdentifier? {
        guard let self else {
            return nil
        }
        return MACIdentifierStruct(value: self).any
    }
}

public extension LocalIdentifier {
    var any: AnyLocalIdentifier {
        AnyLocalIdentifier(object: self)
    }
}

public extension MACIdentifier {
    var any: AnyMACIdentifier {
        AnyMACIdentifier(object: self)
    }
}
