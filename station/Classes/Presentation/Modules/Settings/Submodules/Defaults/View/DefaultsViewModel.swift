import Foundation

class DefaultsViewModel: Identifiable {
    var id = UUID().uuidString

    var title: String?
    var boolean: Observable<Bool?> = Observable<Bool?>()
    var integer: Observable<Int?> = Observable<Int?>()
    var unit: DefaultsIntegerUnit = .seconds
}

enum DefaultsIntegerUnit {
    case minutes
    case seconds
}
