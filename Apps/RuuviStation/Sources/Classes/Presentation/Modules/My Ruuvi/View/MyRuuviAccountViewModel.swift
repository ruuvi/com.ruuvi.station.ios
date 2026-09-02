import Foundation

struct MyRuuviAccountViewModel {
    let username: Observable<String?> = .init()
    let marketingPreference: Observable<Bool?> = .init()
    let marketingPreferenceEnabled: Observable<Bool?> = .init()
    let marketingPreferenceStatusMessage: Observable<String?> = .init()
    let showMarketingPreference: Observable<Bool?> = .init()
}
