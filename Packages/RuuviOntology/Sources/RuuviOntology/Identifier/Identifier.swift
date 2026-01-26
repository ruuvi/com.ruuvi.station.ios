import Foundation

public protocol Identifier: Sendable {
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

    /// Normalizes a MAC address string and extracts its last 3 bytes
    /// (6 hex characters). If the string is shorter than 6 characters,
    /// the entire cleaned string is returned.
    private func last3Bytes(of mac: String) -> String {
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        // Remove non-hex characters, convert to lowercase
        let cleaned = mac.unicodeScalars
            .filter { hexCharacterSet.contains($0) }
            .map { Character($0).lowercased() }
            .joined()

        // Return last 6 hex characters (3 bytes), or shorter if not available
        return cleaned.count > 6
            ? String(cleaned.suffix(6))
            : cleaned
    }

    public static func == (lhs: AnyMACIdentifier, rhs: AnyMACIdentifier) -> Bool {
        lhs.last3Bytes(of: lhs.value) == rhs.last3Bytes(of: rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(last3Bytes(of: value))
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

    private func cleanedHexString() -> String {
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return self.unicodeScalars
            .filter { hexCharacterSet.contains($0) }
            .map { Character($0).lowercased() }
            .joined()
    }

    func isLast3BytesEqual(to other: String) -> Bool {
        let last3Self = cleanedHexString()
        let last3Other = other.cleanedHexString()
        let suffixSelf = last3Self.count >= 6 ? String(last3Self.suffix(6)) : last3Self
        let suffixOther = last3Other.count >= 6 ? String(last3Other.suffix(6)) : last3Other
        return suffixSelf == suffixOther
    }
}

public extension String? {
    var luid: LocalIdentifier? {
        guard let self
        else {
            return nil
        }
        return LocalIdentifierStruct(value: self).any
    }

    var mac: MACIdentifier? {
        guard let self
        else {
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
