import Foundation

struct AddMacViewModel {
    var canSendMac: Observable<Bool?> = .init(false)
    var pasteboardDetectedMacs: Observable<[String]?> = .init([])
}
