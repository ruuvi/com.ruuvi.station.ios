import Foundation

struct NetworkSettingsViewModel {
    var networkFeatureEnabled: Observable<Bool?> = Observable<Bool?>()
    var whereOSNetworkEnabled: Observable<Bool?> = Observable<Bool?>()
    var kaltiotNetworkEnabled: Observable<Bool?> = Observable<Bool?>()
    var kaltiotApiKey: Observable<String?> = Observable<String?>()
}
