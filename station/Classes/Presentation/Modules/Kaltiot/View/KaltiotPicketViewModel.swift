import Foundation

struct KaltiotPickerViewModel {
    var beacons: [ReloadableCell<KaltiotBeaconViewModel>] = []
}

struct KaltiotBeaconViewModel: Equatable {
    let beacon: KaltiotBeacon
    let isConnectable: Bool

    init(beacon: KaltiotBeacon) {
        self.beacon = beacon
        if let sensors = beacon.meta?.capabilities.sensors {
            isConnectable = sensors.contains(.temperature)
                && sensors.contains(.pressure)
                && sensors.contains(.humidity)
        } else {
            isConnectable = false
        }
    }

    static func == (lhs: KaltiotBeaconViewModel, rhs: KaltiotBeaconViewModel) -> Bool {
        return lhs.beacon.id == rhs.beacon.id
    }
}
