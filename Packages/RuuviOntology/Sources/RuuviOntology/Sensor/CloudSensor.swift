import Foundation

public extension CloudSensor {
    var ruuviTagSensor: RuuviTagSensor {
        RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: nil,
            luid: nil,
            macId: id.mac,
            isConnectable: true,
            name: name.isEmpty ? id : name,
            isClaimed: isOwner,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(email: String) -> CloudSensor {
        CloudSensorStruct(
            id: id,
            name: name,
            isClaimed: email == owner,
            isOwner: email == owner,
            owner: owner,
            ownersPlan: ownersPlan,
            picture: picture,
            offsetTemperature: offsetTemperature,
            offsetHumidity: offsetHumidity,
            offsetPressure: offsetPressure,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
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
    public var offsetTemperature: Double?
    public var offsetHumidity: Double?
    public var offsetPressure: Double?
    public var isCloudSensor: Bool?
    public var canShare: Bool
    public var sharedTo: [String]
    public var ownersPlan: String?
    public var maxHistoryDays: Int?

    public init(
        id: String,
        name: String,
        isClaimed: Bool,
        isOwner: Bool,
        owner: String?,
        ownersPlan: String?,
        picture: URL?,
        offsetTemperature: Double?,
        offsetHumidity: Double?,
        offsetPressure: Double?,
        isCloudSensor: Bool?,
        canShare: Bool,
        sharedTo: [String],
        maxHistoryDays: Int?
    ) {
        self.id = id
        self.name = name
        self.isClaimed = isClaimed
        self.isOwner = isOwner
        self.owner = owner
        self.ownersPlan = ownersPlan
        self.picture = picture
        self.offsetTemperature = offsetTemperature
        self.offsetHumidity = offsetHumidity
        self.offsetPressure = offsetPressure
        self.isCloudSensor = isCloudSensor
        self.canShare = canShare
        self.sharedTo = sharedTo
        self.maxHistoryDays = maxHistoryDays
    }
}

public extension CloudSensor {
    var any: AnyCloudSensor {
        AnyCloudSensor(object: self)
    }
}

public struct AnyCloudSensor: CloudSensor, Equatable, Hashable, Reorderable {
    private let object: CloudSensor

    public init(object: CloudSensor) {
        self.object = object
    }

    public var id: String {
        object.id
    }

    public var name: String {
        object.name
    }

    public var isClaimed: Bool {
        object.isClaimed
    }

    public var isOwner: Bool {
        object.isOwner
    }

    public var owner: String? {
        object.owner
    }

    public var ownersPlan: String? {
        object.ownersPlan
    }

    public var picture: URL? {
        object.picture
    }

    public var offsetTemperature: Double? {
        object.offsetTemperature
    }

    public var offsetHumidity: Double? {
        object.offsetHumidity
    }

    public var offsetPressure: Double? {
        object.offsetPressure
    }

    public var isCloudSensor: Bool? {
        object.isCloudSensor
    }

    public var canShare: Bool {
        object.canShare
    }

    public var sharedTo: [String] {
        object.sharedTo
    }

    public var maxHistoryDays: Int? {
        object.maxHistoryDays
    }

    public static func == (lhs: AnyCloudSensor, rhs: AnyCloudSensor) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var orderElement: String {
        id
    }
}
