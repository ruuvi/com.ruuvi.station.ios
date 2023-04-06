import Foundation

protocol ASSelectionViewOutput {
    func viewDidLoad()
    func viewDidSelectItem(item: SelectionItemProtocol,
                           type: AppearanceSettingType)
}
