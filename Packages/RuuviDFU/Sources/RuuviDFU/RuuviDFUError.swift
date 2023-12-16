import Foundation

public struct RuuviDfuError: Error {
    public let description: String
    public init(description: String) {
        self.description = description
    }
}
