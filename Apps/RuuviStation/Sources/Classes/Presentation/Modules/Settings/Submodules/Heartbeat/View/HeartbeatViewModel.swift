import Foundation
import RuuviLocalization

class HeartbeatViewModel {
    var bgScanningState = Observable<Bool?>()
    var bgScanningInterval = Observable<Int?>(1)

    var bgScanningTitle: String {
        RuuviLocalization.Settings.BackgroundScanning.title
    }

    var bgScanningIntervalTitle: String {
        RuuviLocalization.Settings.BackgroundScanning.interval
    }
}
