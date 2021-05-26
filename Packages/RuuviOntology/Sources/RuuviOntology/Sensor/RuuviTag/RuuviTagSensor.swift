import Foundation

public protocol RuuviTagSensor: PhysicalSensor, Versionable, Networkable {}

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
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name,
                                    networkProvider: networkProvider,
                                    isClaimed: isClaimed,
                                    isOwner: isOwner,
                                    owner: owner)
    }

    public func with(version: Int) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name,
                                    networkProvider: networkProvider,
                                    isClaimed: isClaimed,
                                    isOwner: isOwner,
                                    owner: owner)
    }

    public func with(macId: MACIdentifier) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name,
                                    networkProvider: networkProvider,
                                    isClaimed: isClaimed,
                                    isOwner: isOwner,
                                    owner: owner)
    }

    public func withoutMac() -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: nil,
                                    isConnectable: isConnectable,
                                    name: name,
                                    networkProvider: networkProvider,
                                    isClaimed: isClaimed,
                                    isOwner: isOwner,
                                    owner: owner)
    }

    public func with(isConnectable: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name,
                                    networkProvider: networkProvider,
                                    isClaimed: isClaimed,
                                    isOwner: isOwner,
                                    owner: owner)
    }

    public var isNetworkConnectable: Bool {
        return networkProvider != nil
    }
}

public struct RuuviTagSensorStruct: RuuviTagSensor {
    public var version: Int
    public var luid: LocalIdentifier? // local unqiue id
    public var macId: MACIdentifier?
    public var isConnectable: Bool
    public var name: String
    public var networkProvider: RuuviNetworkProvider?
    public var isClaimed: Bool
    public var isOwner: Bool
    public var owner: String?

    public init(
        version: Int,
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        isConnectable: Bool,
        name: String,
        networkProvider: RuuviNetworkProvider?,
        isClaimed: Bool,
        isOwner: Bool,
        owner: String?
    ) {
        self.version = version
        self.luid = luid
        self.macId = macId
        self.isConnectable = isConnectable
        self.name = name
        self.networkProvider = networkProvider
        self.isClaimed = isClaimed
        self.isOwner = isOwner
        self.owner = owner
    }
}

public struct AnyRuuviTagSensor: RuuviTagSensor, Equatable, Hashable, Reorderable {
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
    public var networkProvider: RuuviNetworkProvider? {
        return object.networkProvider
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
