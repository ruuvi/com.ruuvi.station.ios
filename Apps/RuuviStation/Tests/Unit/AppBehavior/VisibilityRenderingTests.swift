import RuuviLocal
import RuuviOntology
import SwiftUI
import UIKit
import XCTest
@testable import station

@MainActor final class VisibilityRenderingTests: XCTestCase {
    func testDefaultCustomAndEmptyStatesRenderInBothDashboardStyles() async throws {
        let fixture = MeasurementFixture()
        fixture.snapshot.displayData.name = "Visibility preview"
        fixture.snapshot.displayData.hasNoData = false
        fixture.snapshot.lastUpdated = Date()
        fixture.snapshot.latestRawRecord = fixture.record()
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [
            fixture.indicator(.init(type: .temperature, temperatureUnit: .celsius)),
            .init(
                variant: .init(type: .co2), value: "800", unit: "ppm", isProminent: false,
                showSubscript: false, tintColor: nil, qualityState: nil),
        ])
        var rendered = Set<Data>()
        for dashboard: DashboardType in [.image, .simple] {
            for mode in 0..<3 {
                let state = VisibilitySettingsViewState()
                state.viewModel = .init(
                    descriptionText: "Choose visible measurements", useDefault: mode == 0,
                    visibleItems: mode == 2 ? [] : [.init(variant: .init(type: .co2), title: "Carbon dioxide")],
                    hiddenItems: mode == 2 ? [] : [.init(variant: .init(type: .pm25), title: "PM2.5")],
                    preview: mode == 2 ? nil : .init(snapshot: fixture.snapshot, dashboardType: dashboard)
                )
                var toggles: [Bool] = []
                let root = VisibilitySettingsView(
                    state: state, onToggleUseDefault: { toggles.append($0) },
                    onHideVisible: { _ in }, onShowHidden: { _ in }, onStartVisibleMove: {},
                    onMoveVisible: { _, _ in }, onFinishVisibleMove: {}
                )
                let host = UIHostingController(rootView: root)
                host.overrideUserInterfaceStyle = mode == 1 ? .dark : .light
                let scene = try XCTUnwrap(
                    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 393, height: 1000)
                window.rootViewController = host
                host.loadViewIfNeeded()
                host.view.frame = window.bounds
                window.isHidden = false
                defer { window.isHidden = true; window.rootViewController = nil }
                host.view.layoutIfNeeded()
                try? await Task.sleep(nanoseconds: 50_000_000)
                host.view.layoutIfNeeded()
                let toggle = try XCTUnwrap(host.view.allDescendants.compactMap { $0 as? UISwitch }.first)
                XCTAssertEqual(toggle.isOn, mode == 0)
                let preview = host.view.allDescendants.compactMap { $0 as? DashboardCellPreviewContainerView }
                XCTAssertEqual(preview.isEmpty, mode == 2)
                if mode != 2 {
                    XCTAssertTrue(
                        host.view.allDescendants.compactMap { $0 as? UILabel }
                            .contains { $0.text == "Visibility preview" })
                }
                let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { context in
                    host.view.layer.render(in: context.cgContext)
                }
                let data = try XCTUnwrap(image.pngData())
                XCTAssertGreaterThan(data.count, 5000)
                rendered.insert(data)
                if mode == 1 {
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "Visibility settings \(dashboard.rawValue)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                toggle.setOn(mode != 0, animated: false)
                toggle.sendActions(for: .valueChanged)
                XCTAssertEqual(toggles, [mode != 0], "One switch interaction must produce one command")
                window.isHidden = true
                window.rootViewController = nil
            }
        }
        XCTAssertGreaterThanOrEqual(rendered.count, 5, "Customisation and preview styles must change the rendered page")
    }

    func testControllerForwardsLifecycleAndBackNavigationAndDisplaysUpdatedState() async throws {
        let fixture = MeasurementFixture()
        let controller = VisibilitySettingsViewController()
        let output = VisibilityControllerOutput()
        controller.output = output
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller.view.layoutIfNeeded()
        XCTAssertEqual(output.loads, 1)
        controller.display(
            viewModel: .init(
                descriptionText: "Configured", useDefault: false,
                visibleItems: [.init(variant: .init(type: .temperature), title: "Temperature")],
                hiddenItems: [], preview: .init(snapshot: fixture.snapshot, dashboardType: .simple)
            ))
        controller.setSaving(true)
        controller.setUseDefaultSwitch(isOn: true)
        try? await Task.sleep(nanoseconds: 50_000_000)
        controller.view.layoutIfNeeded()
        let toggle = try XCTUnwrap(controller.view.allDescendants.compactMap { $0 as? UISwitch }.first)
        XCTAssertTrue(toggle.isOn)
        toggle.setOn(false, animated: false)
        toggle.sendActions(for: .valueChanged)
        XCTAssertEqual(output.toggles, [false])
        controller.setSaving(false)
        controller.backButtonDidTap()
        controller.viewWillDisappear(false)
        XCTAssertEqual(output.dismissals, 1)
        XCTAssertEqual(output.disappearances, 1)
    }
}

private final class VisibilityControllerOutput: VisibilitySettingsViewOutput {
    var loads = 0
    var dismissals = 0
    var disappearances = 0
    var toggles: [Bool] = []
    func viewDidLoad() { loads += 1 }
    func viewDidAskToDismiss() { dismissals += 1 }
    func viewWillDisappear() { disappearances += 1 }
    func viewDidToggleUseDefault(isOn: Bool) { toggles.append(isOn) }
    func viewDidRequestHideItem(at index: Int) {}
    func viewDidRequestShowItem(at index: Int) {}
    func viewDidStartReorderingVisibleItems() {}
    func viewDidMoveVisibleItem(from sourceIndex: Int, to destinationIndex: Int) {}
    func viewDidFinishReorderingVisibleItems() {}
}
