import Foundation

protocol TagsManagerViewOutput {
    func viewDidLoad()
    func viewDidSignOutButtonTap()
    func viewDidCloseButtonTap()
    func viewDidTapAction(_ action: TagManagerActionType)
}
