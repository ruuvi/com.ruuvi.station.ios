import Combine

final class VisibilitySettingsViewState: ObservableObject {
    @Published var viewModel: VisibilitySettingsViewModel = .empty
    @Published var isSaving: Bool = false
}
