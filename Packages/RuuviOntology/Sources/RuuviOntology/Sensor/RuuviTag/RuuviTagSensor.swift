// swiftlint:disable file_length
import Foundation

public protocol RuuviTagSensor: PhysicalSensor,
                                Versionable,
                                Claimable,
                                Connectable,
                                Nameable,
                                Shareable,
                                HistoryFetchable,
                                BackgroundScanable {}

public enum SensorOwnership {
    case claimedByMe
    case sharedWithMe
    case locallyAddedButNotMine
    case locallyAddedAndNotClaimed
}

public extension RuuviTagSensor {
    var id: String {
        if let macId,
           !macId.value.isEmpty {
            macId.value
        } else if let luid {
            luid.value
        } else {
            fatalError()
        }
    }

    var ownership: SensorOwnership {
        switch (isClaimed, isCloud, isOwner) {
        case (true, _, _):
            return .claimedByMe
        case (false, true, false):
            return .sharedWithMe
        case (false, _, false):
            return .locallyAddedButNotMine
        case (false, _, true):
            return .locallyAddedAndNotClaimed
        }
    }

    var any: AnyRuuviTagSensor {
        AnyRuuviTagSensor(object: self)
    }

    var `struct`: RuuviTagSensorStruct {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(isClaimed: Bool) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(isOwner: Bool) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(version: Int) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(firmwareVersion: String) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(name: String) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(owner: String) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(ownersPlan: String) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(macId: MACIdentifier) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(luid: LocalIdentifier) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func withoutMac() -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: nil,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func withoutOwner() -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: nil,
            ownersPlan: nil,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(isConnectable: Bool) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(cloudSensor: CloudSensor) -> RuuviTagSensor {
        let sensor = RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: cloudSensor.name.isEmpty ? cloudSensor.id : cloudSensor.name,
            isClaimed: cloudSensor.isOwner,
            isOwner: cloudSensor.isOwner,
            owner: cloudSensor.owner,
            ownersPlan: cloudSensor.ownersPlan,
            isCloudSensor: cloudSensor.isCloudSensor ?? true,
            canShare: cloudSensor.canShare,
            sharedTo: cloudSensor.sharedTo,
            maxHistoryDays: cloudSensor.maxHistoryDays
        )
        return sensor
    }

    func with(isCloudSensor: Bool) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func unclaimed() -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: false,
            isOwner: true,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: false,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(sharedTo: [String]) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(canShare: Bool) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    func with(maxHistoryDays: Int) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            serviceUUID: serviceUUID,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            ownersPlan: ownersPlan,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo,
            maxHistoryDays: maxHistoryDays
        )
    }

    /// This is a computed property to unwrap the optional isCloudSensor property from database
    /// The property returns false if isCloudSensor is nil, otherwise returns the stored value
    var isCloud: Bool {
        isCloudSensor ?? false
    }
}

public struct RuuviTagSensorStruct: RuuviTagSensor {
    public var version: Int
    public var firmwareVersion: String?
    public var luid: LocalIdentifier? // local unqiue id
    public var macId: MACIdentifier?
    public var serviceUUID: String?
    public var isConnectable: Bool
    public var name: String
    public var isClaimed: Bool
    public var isOwner: Bool
    public var owner: String?
    public var ownersPlan: String?
    public var isCloudSensor: Bool?
    public var canShare: Bool
    public var sharedTo: [String]
    public var maxHistoryDays: Int?

    public init(
        version: Int,
        firmwareVersion: String?,
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        serviceUUID: String?,
        isConnectable: Bool,
        name: String,
        isClaimed: Bool,
        isOwner: Bool,
        owner: String?,
        ownersPlan: String?,
        isCloudSensor: Bool?,
        canShare: Bool,
        sharedTo: [String],
        maxHistoryDays: Int?
    ) {
        self.version = version
        self.firmwareVersion = firmwareVersion
        self.luid = luid
        self.macId = macId
        self.serviceUUID = serviceUUID
        self.isConnectable = isConnectable
        self.name = name
        self.isClaimed = isClaimed
        self.isOwner = isOwner
        self.owner = owner
        self.ownersPlan = ownersPlan
        self.isCloudSensor = isCloudSensor
        self.canShare = canShare
        self.sharedTo = sharedTo
        self.maxHistoryDays = maxHistoryDays
    }
}

public struct AnyRuuviTagSensor: RuuviTagSensor, Equatable, Hashable, Reorderable, Shareable {
    var object: RuuviTagSensor

    public init(object: RuuviTagSensor) {
        self.object = object
    }

    public var id: String {
        object.id
    }

    public var version: Int {
        object.version
    }

    public var firmwareVersion: String? {
        object.firmwareVersion
    }

    public var luid: LocalIdentifier? {
        object.luid
    }

    public var macId: MACIdentifier? {
        object.macId
    }

    public var serviceUUID: String? {
        object.serviceUUID
    }

    public var isConnectable: Bool {
        object.isConnectable
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

    public var isCloudSensor: Bool? {
        object.isCloudSensor
    }

    public var canShare: Bool {
        object.canShare
    }

    public var sharedTo: [String] {
        object.sharedTo.filter {
            !$0.isEmpty
        }
    }

    public var maxHistoryDays: Int? {
        object.maxHistoryDays
    }

    public static func == (lhs: AnyRuuviTagSensor, rhs: AnyRuuviTagSensor) -> Bool {
        let idIsEqual = lhs.id == rhs.id
        var luidIsEqual = false
        if let lhsLuid = lhs.luid?.value, let rhsLuid = rhs.luid?.value {
            luidIsEqual = lhsLuid == rhsLuid
        }
        var macIsEqual = false
        if let lhsMac = lhs.macId?.value, let rhsMac = rhs.macId?.value {
            macIsEqual = lhsMac == rhsMac
        }
        return idIsEqual || luidIsEqual || macIsEqual
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var orderElement: String {
        id
    }
}
