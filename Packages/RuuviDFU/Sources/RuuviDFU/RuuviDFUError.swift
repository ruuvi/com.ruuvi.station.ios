import Foundation
import RuuviLocalization

public struct RuuviDfuError: Error {
    public static let invalidFirmwareFile = RuuviDfuError(
        description: RuuviLocalization.RuuviDfuError.invalidFirmwareFile
    )
    public static let failedToConstructUUID = RuuviDfuError(
        description: RuuviLocalization.RuuviDfuError.failedToConstructUUID
    )
    public let description: String
    public init(description: String) {
        self.description = description
    }
}
