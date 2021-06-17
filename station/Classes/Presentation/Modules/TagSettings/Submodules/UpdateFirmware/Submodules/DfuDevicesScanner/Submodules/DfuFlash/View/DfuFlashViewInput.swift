import Foundation

enum DfuFlashState: String, CaseIterable {
    case packageSelection = "DfuFlash.Steps.PackageSelection.text"
    case readyForUpload = "DfuFlash.Steps.ReadyForUpload.text"
    case uploading = "DfuFlash.Steps.Uploading.text"
    case completed = "DfuFlash.Steps.Completed.text"
}

protocol DfuFlashViewInput: ViewInput {
    var dfuFlashState: DfuFlashState { get set }
    var viewModel: DfuFlashViewModel { get set }

    func showCancelFlashDialog()
}
