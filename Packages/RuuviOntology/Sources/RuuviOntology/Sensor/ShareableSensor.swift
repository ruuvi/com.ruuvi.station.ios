import Foundation

public struct ShareableSensorStruct: ShareableSensor {
    public var id: String
    public var canShare: Bool
    public var sharedTo: [String]

    public init(
        id: String,
        canShare: Bool,
        sharedTo: [String]
    ) {
        self.id = id
        self.canShare = canShare
        self.sharedTo = sharedTo
    }
}

extension ShareableSensor {
    public var any: AnyShareableSensor {
        return AnyShareableSensor(object: self)
    }
}

public struct AnyShareableSensor: ShareableSensor, Equatable, Hashable, Reorderable {
    private let object: ShareableSensor

    public init(object: ShareableSensor) {
        self.object = object
    }

    public var id: String {
        return object.id
    }

    public var canShare: Bool {
        return object.canShare
    }

    public var sharedTo: [String] {
        return object.sharedTo
    }

    public static func == (lhs: AnyShareableSensor, rhs: AnyShareableSensor) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var orderElement: String {
        return id
    }
}
