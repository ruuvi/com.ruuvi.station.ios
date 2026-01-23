import Foundation

protocol VisibilitySettingsViewOutput: AnyObject {
    func viewDidLoad()
    func viewDidAskToDismiss()
    func viewWillDisappear()
    func viewDidToggleUseDefault(isOn: Bool)
    func viewDidRequestHideItem(at index: Int)
    func viewDidRequestShowItem(at index: Int)
    func viewDidStartReorderingVisibleItems()
    func viewDidMoveVisibleItem(
        from sourceIndex: Int,
        to destinationIndex: Int
    )
    func viewDidFinishReorderingVisibleItems()
}
