import Foundation
import RuuviLocalization

class HeartbeatViewModel {
    var bgScanningState = Observable<Bool?>()
    var bgScanningInterval = Observable<Int?>(1)

    var bgScanningTitle: String {
        return RuuviLocalization.Settings.BackgroundScanning.title
    }

    var bgScanningIntervalTitle: String {
        return RuuviLocalization.Settings.BackgroundScanning.interval
    }
}
