import Foundation
import RuuviOntology

public struct RuuviCloudPNTokenListResponse: Decodable {
    public let tokens: [CloudPNTokens]?

    public struct CloudPNTokens: Decodable {
        public let id: Int
        public let lastAccessed: TimeInterval?
        public let name: String?
    }

    public var anyTokens: [RuuviCloudPNToken] {
        guard let tokens else {
            return []
        }
        return tokens.map {
            RuuviCloudPNTokenStruct(
                id: $0.id,
                lastAccessed: $0.lastAccessed,
                name: $0.name
            )
        }
    }
}
