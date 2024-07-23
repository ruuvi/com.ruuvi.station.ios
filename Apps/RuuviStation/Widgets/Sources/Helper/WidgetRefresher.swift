import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct WidgetRefresher: AppIntent {
    static var title = LocalizedStringResource("Widgets.Refresh.Manual.title")

    @MainActor
    func perform() async throws -> some IntentResult {
        let viewModel = WidgetViewModel()
        viewModel.foceRefreshWidget(true)
        return .result()
    }
}
