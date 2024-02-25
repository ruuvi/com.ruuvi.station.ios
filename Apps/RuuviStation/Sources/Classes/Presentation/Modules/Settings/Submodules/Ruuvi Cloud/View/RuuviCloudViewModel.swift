import Foundation

class RuuviCloudViewModel: Identifiable {
    var id = UUID().uuidString

    var title: String?
    var boolean: Observable<Bool?> = .init()
    var hideStatusLabel: Observable<Bool?> = .init()
}
