import Foundation

struct AddMacViewModel {
    var title: Observable<String?> = .init(nil)
    var canSendMac: Observable<Bool?> = .init(false)
    var pasteboardDetectedMacs: Observable<[String]?> = .init([])
}
