import Foundation

public struct DFULog {
    public let message: String
    public let time: Date

    public init(message: String, time: Date) {
        self.message = message
        self.time = time
    }
}
