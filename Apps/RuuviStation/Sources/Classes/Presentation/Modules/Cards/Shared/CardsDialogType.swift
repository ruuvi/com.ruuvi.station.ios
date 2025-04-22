enum CardsDialogType: Identifiable, Equatable {
    case bluetoothDisabled
    case keepConnection(viewModel: CardsViewModel, targetTab: CardsTabType)
    case firmwareUpdate(viewModel: CardsViewModel)
    case firmwareDismissConfirmation(viewModel: CardsViewModel)

    var id: String {
        switch self {
        case .bluetoothDisabled:
            return "bluetoothDisabled"
        case .keepConnection(let viewModel, let targetTab):
            return "keepConnection-\(viewModel.id ?? "")-\(targetTab.rawValue)"
        case .firmwareUpdate(let viewModel):
            return "firmwareUpdate-\(viewModel.id ?? "")"
        case .firmwareDismissConfirmation(let viewModel):
            return "firmwareDismissConfirmation-\(viewModel.id ?? "")"
        }
    }
}
