import BTKit
import Foundation

protocol DiscoveryBluetoothTransport: AnyObject {
    var state: BTScannerState { get }
    func scan(_ receive: @escaping (RuuviTag) -> Void) -> () -> Void
    func observeState(_ receive: @escaping (BTScannerState) -> Void) -> () -> Void
    func observeLost(_ receive: @escaping (RuuviTag) -> Void) -> () -> Void
}

final class BTKitDiscoveryTransport: NSObject, DiscoveryBluetoothTransport {
    private let foreground: BTForeground
    init(foreground: BTForeground) { self.foreground = foreground }
    var state: BTScannerState { foreground.bluetoothState }
    func scan(_ receive: @escaping (RuuviTag) -> Void) -> () -> Void {
        let token = foreground.scan(self) { _, device in
            if let tag = device.ruuvi?.tag { receive(tag) }
        }
        return { token.invalidate() }
    }
    func observeState(_ receive: @escaping (BTScannerState) -> Void) -> () -> Void {
        let token = foreground.state(self) { _, state in receive(state) }
        return { token.invalidate() }
    }
    func observeLost(_ receive: @escaping (RuuviTag) -> Void) -> () -> Void {
        let token = foreground.lost(self, options: [.lostDeviceDelay(10)]) { _, device in
            if let tag = device.ruuvi?.tag { receive(tag) }
        }
        return { token.invalidate() }
    }
}
