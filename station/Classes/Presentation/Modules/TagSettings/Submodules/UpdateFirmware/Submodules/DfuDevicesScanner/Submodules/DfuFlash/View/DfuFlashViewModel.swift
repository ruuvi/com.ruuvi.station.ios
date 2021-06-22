import Foundation
import RuuviDFU

class DfuFlashViewModel: NSObject {
    var flashProgress: Observable<Float?> = Observable<Float?>()
    var flashLogs: Observable<[DFULog]?> = Observable<[DFULog]?>()
}
