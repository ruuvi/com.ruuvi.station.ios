import Foundation

extension CloudSensor {
    public var ruuviTagSensor: RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: 5,
            luid: nil,
            macId: id.mac,
            isConnectable: true,
            name: name.isEmpty ? id : name,
            isClaimed: isOwner,
            isOwner: isOwner,
            owner: owner
        )
    }

    public func with(email: String) -> CloudSensor {
        return CloudSensorStruct(
            id: id,
            name: name,
            isClaimed: email == owner,
            isOwner: email == owner,
            owner: owner,
            picture: picture
        )
    }
}

public struct CloudSensorStruct: CloudSensor {
    public var id: String
    public var name: String
    public var isClaimed: Bool
    public var isOwner: Bool
    public var owner: String?
    public var picture: URL?

    public init(
        id: String,
        name: String,
        isClaimed: Bool,
        isOwner: Bool,
        owner: String?,
        picture: URL?
    ) {
        self.id = id
        self.name = name
        self.isClaimed = isClaimed
        self.isOwner = isOwner
        self.owner = owner
        self.picture = picture
    }
}

extension CloudSensor {
    public var any: AnyCloudSensor {
        return AnyCloudSensor(object: self)
    }
}

public struct AnyCloudSensor: CloudSensor, Equatable, Hashable, Reorderable {
    private let object: CloudSensor

    public init(object: CloudSensor) {
        self.object = object
    }

    public var id: String {
        return object.id
    }

    public var name: String {
        return object.name
    }

    public var isClaimed: Bool {
        return object.isClaimed
    }

    public var isOwner: Bool {
        return object.isOwner
    }

    public var owner: String? {
        return object.owner
    }

    public var picture: URL? {
        return object.picture
    }

    public static func == (lhs: AnyCloudSensor, rhs: AnyCloudSensor) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var orderElement: String {
        return id
    }
}
