import Foundation

enum DefaultsType {
    case switcher
    case stepper
    case plain
}

enum DefaultItem {
    case imageCompressionQuality
    case graphDownsampleMaximumPoints
    case other
}

class DefaultsViewModel: Identifiable {
    var id = UUID().uuidString

    var title: String?
    var type: Observable<DefaultsType?> = .init()
    var item: Observable<DefaultItem?> = .init()
    // Value for switcher type
    var boolean: Observable<Bool?> = .init()
    var hideStatusLabel: Observable<Bool?> = .init(false)
    // Value for stepper type
    var integer: Observable<Int?> = .init()
    // Value for plain type
    var value: Observable<String?> = .init()
    var unit: DefaultsIntegerUnit = .seconds
}

enum DefaultsIntegerUnit {
    case hours
    case minutes
    case seconds
    case decimal
}
