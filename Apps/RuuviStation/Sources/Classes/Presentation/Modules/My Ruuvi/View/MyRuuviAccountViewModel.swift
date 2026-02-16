import Foundation

struct MyRuuviAccountViewModel {
    let username: Observable<String?> = .init()
    let marketingPreference: Observable<Bool?> = .init()
}
