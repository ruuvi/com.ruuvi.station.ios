import Foundation

class HeartbeatViewModel {
    var bgScanningState = Observable<Bool?>()
    var bgScanningInterval = Observable<Int?>(1)

    var bgScanningTitle: String {
        return "Settings.BackgroundScanning.title".localized()
    }

    var bgScanningIntervalTitle: String {
        return "Settings.BackgroundScanning.interval".localized()
    }
}
