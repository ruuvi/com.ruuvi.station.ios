import Foundation

struct ShareViewModel {
    let sharedEmails: Observable<[String]?> = .init()
    let canShare: Observable<Bool?> = .init(false)
    let maxCount: Int

    var sharedToCount: Int {
        return sharedEmails.value?.count ?? 0
    }
}
