import Foundation

struct AboutViewModel {
    var version: Observable<String?> = .init()
    var addedTags: Observable<String?> = .init()
    var storedMeasurements: Observable<String?> = .init()
    var databaseSize: Observable<String?> = .init()
}
