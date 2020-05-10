import Foundation

struct NetworkSettingsViewModel {
    var networkFeatureEnabled: Observable<Bool?> = Observable<Bool?>()
    var kaltiotApiKey: Observable<String?> = Observable<String?>()
    var whereOSNetworkEnabled: Observable<Bool?> = Observable<Bool?>()
}
