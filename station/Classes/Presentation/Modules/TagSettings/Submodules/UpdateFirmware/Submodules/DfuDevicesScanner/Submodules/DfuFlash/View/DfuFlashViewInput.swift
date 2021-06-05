import Foundation

enum DfuFlashState: String, CaseIterable {
    case packageSelection = "Package Selection"
    case readyForUpload = "Ready For Upload"
    case uploading = "Uploading"
    case completed = "Completed"
}

protocol DfuFlashViewInput: ViewInput {
    var dfuFlashState: DfuFlashState { get set }
    var viewModel: DfuFlashViewModel { get set }

    func showCancelFlashDialog()
}
