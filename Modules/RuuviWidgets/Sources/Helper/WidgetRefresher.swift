import AppIntents
import WidgetKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public enum WidgetRefreshTarget: String, AppEnum {
    case simple
    case multi

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Widget Type")

    public static var caseDisplayRepresentations: [WidgetRefreshTarget: DisplayRepresentation] = [
        .simple: DisplayRepresentation(title: "Simple"),
        .multi: DisplayRepresentation(title: "Multi"),
    ]
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct WidgetRefresher: AppIntent {
    public static var title = LocalizedStringResource(
        "Widgets.Refresh.Manual.title")

    @Parameter(title: "Widget Type")
    public var target: WidgetRefreshTarget

    public init() {
        target = .simple
    }

    public init(target: WidgetRefreshTarget) {
        self.target = target
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
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

@available(iOS 17.0, *)
public struct RuuviWidgetIntentsPackage: AppIntentsPackage {}
