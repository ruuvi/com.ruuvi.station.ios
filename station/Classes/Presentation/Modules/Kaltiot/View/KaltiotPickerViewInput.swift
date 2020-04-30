import Foundation
protocol KaltiotPickerViewInput: ViewInput {
    var viewModel: KaltiotPickerViewModel! { get set }
    func reloadData()
    func applyChanges(_ changes: CellChanges)
}
