import Foundation

public protocol RuuviCloudPNToken {
    var id: Int { get }
    var lastAccessed: TimeInterval? { get }
    var name: String? { get }
}

public struct RuuviCloudPNTokenStruct: RuuviCloudPNToken {
    public var id: Int
    public var lastAccessed: TimeInterval?
    public var name: String?

    public init(id: Int,
                lastAccessed: TimeInterval? = nil,
                name: String? = nil)
    {
        self.id = id
        self.lastAccessed = lastAccessed
        self.name = name
    }
}
