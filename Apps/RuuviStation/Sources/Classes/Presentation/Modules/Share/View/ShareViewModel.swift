import Foundation

struct ShareViewModel {
    let sharedEmails: Observable<[String]?> = .init()
    let pendingSharedEmails: Observable<[String]?> = .init()
    let canShare: Observable<Bool?> = .init(false)
    let maxCount: Observable<Int?> = .init(10)
    let totalUsedCount: Observable<Int?> = .init(0)
    let totalAvailableCount: Observable<Int?> = .init(0)

    var sharedToCount: Int {
        sharedEmails.value?.count ?? 0
    }

    var pendingSharedToCount: Int {
        pendingSharedEmails.value?.count ?? 0
    }

    var totalShareCount: Int {
        sharedToCount + pendingSharedToCount
    }

    var sensorMaxCount: Int {
        maxCount.value ?? 10
    }

    var planTotalUsedCount: Int {
        totalUsedCount.value ?? 0
    }

    var planTotalAvailableCount: Int {
        totalAvailableCount.value ?? 0
    }
}
