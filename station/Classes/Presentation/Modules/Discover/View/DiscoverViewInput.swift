import Foundation

protocol DiscoverViewInput: ViewInput {
    var devices: [DiscoverDeviceViewModel] { get set }
    var savedDevicesUUIDs: [String] { get set }
    var isBluetoothEnabled: Bool { get set }
}
