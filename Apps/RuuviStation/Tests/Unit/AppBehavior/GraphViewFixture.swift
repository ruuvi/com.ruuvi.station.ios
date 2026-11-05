import DGCharts
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class GraphViewFixture {
    let graph = GraphFixture()
    let controller: GraphTestViewController
    let window: UIWindow
    private let previousWindow: UIWindow?
    let variants: [MeasurementDisplayVariant] = [
        .init(type: .temperature, temperatureUnit: .celsius),
        .init(type: .co2), .init(type: .pm25), .init(type: .voc),
    ]
    init() throws {
        controller = GraphTestViewController(output: graph.presenter, settings: graph.measurements.settings)
        controller.measurementService = graph.measurements.measurement
        graph.presenter.view = controller
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        previousWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.setActiveSnapshot(graph.measurements.snapshot)
        controller.view.layoutIfNeeded()
    }
    func close() {
        graph.cleanup()
        controller.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        previousWindow?.makeKeyAndVisible()
    }
    var charts: [CardsGraphView] { controller.view.allDescendants.compactMap { $0 as? CardsGraphView } }
    func loadCharts() {
        let now = Date().timeIntervalSince1970
        controller.createChartViews(from: variants)
        let models = variants.enumerated().map { index, variant in
            let entries = [
                ChartDataEntry(x: now - 60, y: Double(index + 20)), ChartDataEntry(x: now, y: Double(index + 22)),
            ]
            let data = RuuviGraphDataSetFactory.newDataSet(
                upperAlertValue: 30, entries: entries, lowerAlertValue: 10, showAlertRangeInGraph: true)
            return RuuviGraphViewDataModel(
                upperAlertValue: 30, variant: variant, chartData: LineChartData(dataSet: data), lowerAlertValue: 10)
        }
        controller.setChartViewData(from: models, settings: graph.measurements.settings)
        controller.setHasChartData(true)
        controller.view.layoutIfNeeded()
    }
    func action(_ title: String) throws -> UIAction {
        let actions = controller.view.allDescendants.compactMap { ($0 as? UIButton)?.menu }
            .flatMap { self.actions(in: $0) }
        return try XCTUnwrap(actions.first { $0.title == title }, "Missing menu action: " + title)
    }
    func perform(_ action: UIAction) {
        let button = UIButton()
        button.addAction(action, for: .touchUpInside)
        button.sendActions(for: .touchUpInside)
    }
    private func actions(in menu: UIMenu) -> [UIAction] {
        menu.children.flatMap { element in
            if let action = element as? UIAction { return [action] }
            if let nested = element as? UIMenu { return actions(in: nested) }
            return []
        }
    }
}

/// Capture the system share-sheet boundary while presenting app-owned dialogs normally.
@MainActor final class GraphTestViewController: CardsGraphViewController {
    var requestedShare: UIActivityViewController?
    override func present(
        _ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil
    ) {
        if let share = viewControllerToPresent as? UIActivityViewController {
            requestedShare = share
            completion?()
        } else {
            super.present(viewControllerToPresent, animated: flag, completion: completion)
        }
    }
}
