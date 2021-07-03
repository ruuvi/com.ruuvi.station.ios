import Foundation

public struct RuuviDfuError: Error {
    public static let invalidFirmwareFile = RuuviDfuError(description: "RuuviDfuError.invalidFirmwareFile")
    public static let failedToConstructUUID = RuuviDfuError(description: "RuuviDfuError.failedToConstructUUID") // TODO: @rinat localize
    public let description: String
    public init(description: String) {
        self.description = description
    }
}
