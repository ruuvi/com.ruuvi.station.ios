import Foundation

protocol Identifier {
    var value: String { get }
}

protocol LocalIdentifier: Identifier {
}

protocol MACIdentifier: Identifier {
}

struct MACIdentifierStruct: MACIdentifier {
    var value: String
}

struct AnyMACIdentifier: MACIdentifier, Equatable, Hashable {
    var object: MACIdentifier

    var value: String {
        return object.value
    }

    static func == (lhs: AnyMACIdentifier, rhs: AnyMACIdentifier) -> Bool {
        return lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

struct LocalIdentifierStruct: LocalIdentifier {
    var value: String
}

struct AnyLocalIdentifier: LocalIdentifier, Equatable, Hashable {
    var object: LocalIdentifier

    var value: String {
        return object.value
    }

    static func == (lhs: AnyLocalIdentifier, rhs: AnyLocalIdentifier) -> Bool {
        return lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension String {
    var luid: LocalIdentifier {
        return LocalIdentifierStruct(value: self).any
    }

    var mac: MACIdentifier {
        return MACIdentifierStruct(value: self).any
    }
}

extension LocalIdentifier {
    var any: AnyLocalIdentifier {
        return AnyLocalIdentifier(object: self)
    }
}

extension MACIdentifier {
    var any: AnyMACIdentifier {
        return AnyMACIdentifier(object: self)
    }
}
