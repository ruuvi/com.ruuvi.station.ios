import Foundation

struct NetworkSettingsViewModel {
    var networkFeatureEnabled: Observable<Bool?> = Observable<Bool?>()
    var networkRefreshInterval: Observable<Int?> = Observable<Int?>()
    var minNetworkRefreshInterval: Observable<Double?> = Observable<Double?>()
}
