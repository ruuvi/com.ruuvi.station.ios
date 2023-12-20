import Foundation

protocol OffsetCorrectionViewInput: ViewInput {
    var viewModel: OffsetCorrectionViewModel { get set }

    func showCalibrateDialog()
    func showClearConfirmationDialog()
}
