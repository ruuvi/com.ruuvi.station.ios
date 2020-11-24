import Foundation

struct ShareViewModel {
    let sharedEmails: Observable<[String]?> = .init()
    let maxCount: Int
}
