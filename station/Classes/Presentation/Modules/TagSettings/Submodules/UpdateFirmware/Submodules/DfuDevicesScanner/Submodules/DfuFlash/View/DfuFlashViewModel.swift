import Foundation

class DfuFlashViewModel: NSObject {
    var flashProgress: Observable<Float?> = Observable<Float?>()
    var flashLogs: Observable<[DfuLog]?> = Observable<[DfuLog]?>()
}
