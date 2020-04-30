import Foundation

protocol KaltiotPickerViewOutput {
    func viewDidLoad()
    func viewDidTriggerClose()
    func viewDidTriggerLoadNextPage()
    func viewDidSelectTag(at index: Int)
}
