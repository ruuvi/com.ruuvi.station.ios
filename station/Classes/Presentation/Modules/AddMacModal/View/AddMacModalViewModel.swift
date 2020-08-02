import Foundation

struct AddMacModalViewModel {
    var canSendMac: Observable<Bool?> = .init(false)
    var pasteboardDetectedMacs: Observable<[String]?> = .init([])
}
