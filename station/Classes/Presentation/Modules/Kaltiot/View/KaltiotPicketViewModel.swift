import Foundation

struct KaltiotPickerViewModel {
    var beacons: [ReloadableCell<KaltiotBeaconViewModel>] = []
}

struct KaltiotBeaconViewModel: Equatable {
    let id: String
    let isConnectable: Bool

    init(beacon: KaltiotBeacon) {
        id = beacon.id
        if let sensors = beacon.meta?.capabilities.sensors {
            isConnectable = sensors.contains(.temperature)
                && sensors.contains(.pressure)
                && sensors.contains(.humidity)
        } else {
            isConnectable = false
        }
    }

    static func == (lhs: KaltiotBeaconViewModel, rhs: KaltiotBeaconViewModel) -> Bool {
        return lhs.id == rhs.id
    }
}
