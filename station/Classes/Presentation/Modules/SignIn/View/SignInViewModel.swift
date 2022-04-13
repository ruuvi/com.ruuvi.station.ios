import UIKit

struct SignInViewModel {
    var titleLabelText: Observable<String?> = .init()
    var subTitleLabelText: Observable<String?> = .init()
    var submitButtonText: Observable<String?> = .init()
    var errorLabelText: Observable<String?> = .init()
    var inputText: Observable<String?> = .init()
    var placeholder: Observable<String?> = .init()
    var canPopViewController: Observable<Bool?> = .init(false)
    var showEmailField: Observable<Bool?> = .init(true)
    var showCodeField: Observable<Bool?> = .init(false)
    var showUnderline: Observable<Bool?> = .init(true)
    var isFromDeeplink: Observable<Bool?> = .init(false)
}
