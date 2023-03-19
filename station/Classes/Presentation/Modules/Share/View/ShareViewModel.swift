import Foundation

struct ShareViewModel {
    let sharedEmails: Observable<[String]?> = .init()
    let canShare: Observable<Bool?> = Observable<Bool?>(false)
    let maxCount: Int
}
