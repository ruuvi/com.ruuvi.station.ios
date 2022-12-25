import UIKit

struct SignInViewModel {
    var inputText: Observable<String?> = .init()
    var showVerficationScreen: Observable<Bool?> = .init(false)
    var isFromDeeplink: Observable<Bool?> = .init(false)
}
