// swiftlint:disable file_length
import Foundation

public protocol RuuviTagSensor: PhysicalSensor, Versionable, Claimable, Connectable, Nameable, Shareable {}

extension RuuviTagSensor {
    public var id: String {
        if let macId = macId,
            !macId.value.isEmpty {
            return macId.value
        } else if let luid = luid {
            return luid.value
        } else {
            fatalError()
        }
    }

    public var any: AnyRuuviTagSensor {
        return AnyRuuviTagSensor(object: self)
    }

    public var `struct`: RuuviTagSensorStruct {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(isClaimed: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(isOwner: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(version: Int) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(firmwareVersion: String) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(name: String) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(owner: String) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(macId: MACIdentifier) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func withoutMac() -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: nil,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func withoutOwner() -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: nil,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(isConnectable: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(cloudSensor: CloudSensor) -> RuuviTagSensor {
        let sensor = RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: cloudSensor.name.isEmpty ? cloudSensor.id : cloudSensor.name,
            isClaimed: cloudSensor.isOwner,
            isOwner: cloudSensor.isOwner,
            owner: cloudSensor.owner,
            isCloudSensor: cloudSensor.isCloudSensor ?? true,
            canShare: cloudSensor.canShare,
            sharedTo: cloudSensor.sharedTo
        )
        return sensor
    }

    public func with(isCloudSensor: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func unclaimed() -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: false,
            isOwner: true,
            owner: owner,
            isCloudSensor: false,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(sharedTo: [String]) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    public func with(canShare: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(
            version: version,
            firmwareVersion: firmwareVersion,
            luid: luid,
            macId: macId,
            isConnectable: isConnectable,
            name: name,
            isClaimed: isClaimed,
            isOwner: isOwner,
            owner: owner,
            isCloudSensor: isCloudSensor,
            canShare: canShare,
            sharedTo: sharedTo
        )
    }

    /// This is a computed property to unwrap the optional isCloudSensor property from database
    /// The property returns false if isCloudSensor is nil, otherwise returns the stored value
    public var isCloud: Bool {
        return isCloudSensor ?? false
    }
}

public struct RuuviTagSensorStruct: RuuviTagSensor {
    public var version: Int
    public var firmwareVersion: String?
    public var luid: LocalIdentifier? // local unqiue id
    public var macId: MACIdentifier?
    public var isConnectable: Bool
    public var name: String
    public var isClaimed: Bool
    public var isOwner: Bool
    public var owner: String?
    public var isCloudSensor: Bool?
    public var canShare: Bool
    public var sharedTo: [String]

    public init(
        version: Int,
        firmwareVersion: String?,
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        isConnectable: Bool,
        name: String,
        isClaimed: Bool,
        isOwner: Bool,
        owner: String?,
        isCloudSensor: Bool?,
        canShare: Bool,
        sharedTo: [String]
    ) {
        self.version = version
        self.firmwareVersion = firmwareVersion
        self.luid = luid
        self.macId = macId
        self.isConnectable = isConnectable
        self.name = name
        self.isClaimed = isClaimed
        self.isOwner = isOwner
        self.owner = owner
        self.isCloudSensor = isCloudSensor
        self.canShare = canShare
        self.sharedTo = sharedTo
    }
}

public struct AnyRuuviTagSensor: RuuviTagSensor, Equatable, Hashable, Reorderable, Shareable {
    var object: RuuviTagSensor

    public init(object: RuuviTagSensor) {
        self.object = object
    }

    public var id: String {
        return object.id
    }
    public var version: Int {
        return object.version
    }
    public var firmwareVersion: String? {
        return object.firmwareVersion
    }
    public var luid: LocalIdentifier? {
        return object.luid
    }
    public var macId: MACIdentifier? {
        return object.macId
    }
    public var isConnectable: Bool {
        return object.isConnectable
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
    public var isCloudSensor: Bool? {
        return object.isCloudSensor
    }
    public var canShare: Bool {
        return object.canShare
    }
    public var sharedTo: [String] {
        return object.sharedTo.filter({
            !$0.isEmpty
        })
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
        return id
    }
}
