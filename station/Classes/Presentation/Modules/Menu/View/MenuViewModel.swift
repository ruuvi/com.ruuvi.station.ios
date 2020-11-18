import Foundation

struct MenuViewModel {
    let username: Observable<String?> = Observable<String?>()
    let status: Observable<String?> = Observable<String?>()
    let isSyncing: Observable<Bool?> = Observable<Bool?>()
}
