import Foundation

enum DefaultsType {
    case switcher
    case stepper
    case plain
}
class DefaultsViewModel: Identifiable {
    var id = UUID().uuidString

    var title: String?
    var type: Observable<DefaultsType?> = Observable<DefaultsType?>()
    // Value for switcher type
    var boolean: Observable<Bool?> = Observable<Bool?>()
    // Value for stepper type
    var integer: Observable<Int?> = Observable<Int?>()
    // Value for plain type
    var value: Observable<String?> = Observable<String?>()
    var unit: DefaultsIntegerUnit = .seconds
}

enum DefaultsIntegerUnit {
    case hours
    case minutes
    case seconds
    case decimal
}
