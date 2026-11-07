import BTKit
import Foundation

protocol RuuviConnectionTransport: AnyObject {
    var state: BTScannerState { get }
    func isConnected(uuid: String) -> Bool
    func observeState(_ receive: @escaping (BTScannerState) -> Void) -> () -> Void
}

final class BTKitConnectionTransport: RuuviConnectionTransport {
    private let foreground: BTForeground
    private let background: BTBackground
    init(foreground: BTForeground, background: BTBackground) {
        self.foreground = foreground
        self.background = background
    }
    var state: BTScannerState { foreground.bluetoothState }
    func isConnected(uuid: String) -> Bool { background.isConnected(uuid: uuid) }
    func observeState(_ receive: @escaping (BTScannerState) -> Void) -> () -> Void {
        let token = foreground.state(self) { _, state in receive(state) }
        return { token.invalidate() }
    }
}
