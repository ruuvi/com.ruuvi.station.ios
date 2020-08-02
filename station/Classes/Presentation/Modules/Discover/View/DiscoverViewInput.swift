import Foundation

protocol DiscoverViewInput: ViewInput {
    var devices: [DiscoverDeviceViewModel] { get set }
    var savedDevicesIds: [String] { get set }
    var webTags: [DiscoverWebTagViewModel] { get set }
    var savedWebTagProviders: [WeatherProvider] { get set }
    var isBluetoothEnabled: Bool { get set }
    var isCloseEnabled: Bool { get set }

    func showBluetoothDisabled()
    func showWebTagInfoDialog()
    func showAddKaltiotApiKey()
    func showChoiseDialog()
    var networkFeatureEnabled: Bool { get set }
    var networkKaltiotEnabled: Bool { get set }
    var networkWhereOsEnabled: Bool { get set }
}
