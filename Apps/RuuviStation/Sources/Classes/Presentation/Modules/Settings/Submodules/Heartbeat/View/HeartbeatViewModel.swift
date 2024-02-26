import Foundation
import RuuviLocalization

class HeartbeatViewModel {
    var bgScanningState = Observable<Bool?>()
    var hideSwitchStatusLabel = Observable<Bool?>()
    var bgScanningInterval = Observable<Int?>(1)

    var bgScanningTitle: String {
        RuuviLocalization.Settings.BackgroundScanning.Bluetooth.title
    }

    var bgScanningIntervalTitle: String {
        RuuviLocalization.Settings.BackgroundScanning.interval
    }
}
