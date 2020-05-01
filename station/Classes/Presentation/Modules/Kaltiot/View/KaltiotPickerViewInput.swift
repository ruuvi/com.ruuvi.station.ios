import Foundation
protocol KaltiotPickerViewInput: ViewInput {
    var viewModel: KaltiotPickerViewModel! { get set }
    func applyChanges(_ changes: CellChanges)
}
