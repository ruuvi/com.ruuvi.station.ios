import Foundation

class AdvancedViewModel: Identifiable {
    var id = UUID().uuidString

    var title: String?
    var boolean: Observable<Bool?> = Observable<Bool?>()
    var integer: Observable<Int?> = Observable<Int?>()
    var unit: AdvancedIntegerUnit = .seconds
}

enum AdvancedIntegerUnit {
    case hours
    case minutes
    case seconds
}
