import AppIntents
import WidgetKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum WidgetRefreshTarget: String, AppEnum {
    case simple
    case multi

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Widget Type")

    static var caseDisplayRepresentations: [WidgetRefreshTarget: DisplayRepresentation] = [
        .simple: DisplayRepresentation(title: "Simple"),
        .multi: DisplayRepresentation(title: "Multi"),
    ]
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct WidgetRefresher: AppIntent {
    static var title = LocalizedStringResource("Widgets.Refresh.Manual.title")

    @Parameter(title: "Widget Type")
    var target: WidgetRefreshTarget

    init() {
        target = .simple
    }

    init(target: WidgetRefreshTarget) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let viewModel = WidgetViewModel()
        viewModel.forceRefreshWidget(true)
        switch target {
        case .simple:
            WidgetCenter.shared.reloadTimelines(ofKind: Constants.simpleWidgetKindId.rawValue)
        case .multi:
            WidgetCenter.shared.reloadTimelines(ofKind: Constants.multiSensorWidgetKindId.rawValue)
        }
        return .result()
    }
}
