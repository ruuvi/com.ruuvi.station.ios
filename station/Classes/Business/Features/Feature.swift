import Foundation

public struct Feature: RawRepresentable {
    private let name: String

    public init(rawValue: String) {
        self.name = rawValue
    }
    
    public var rawValue: String {
        return self.name
    }
}

extension Feature: Decodable {
    enum CodingKeys: String, CodingKey {
        case name
    }
}
