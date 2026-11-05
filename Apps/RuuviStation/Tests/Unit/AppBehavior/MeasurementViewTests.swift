import DGCharts
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class MeasurementViewTests: XCTestCase {
    func testEveryMeasurementSheetRendersItsValueAndDescriptionInBothThemes() throws {
        let fixture = MeasurementFixture()
        let types: [MeasurementType] = [
            .temperature, .humidity, .pressure, .aqi, .co2, .pm10, .pm25, .pm40, .pm100,
            .voc, .nox, .luminosity, .soundInstant, .soundAverage, .soundPeak, .voltage,
            .rssi, .accelerationX, .accelerationY, .accelerationZ, .movementCounter,
            .measurementSequenceNumber, .txPower,
        ]
        for style: UIUserInterfaceStyle in [.light, .dark] {
            for type in types {
                let variant = MeasurementDisplayVariant(type: type)
                let indicator = makeIndicator(variant, value: type == .aqi ? "75/100" : "123.45", quality: .good(75))
                fixture.snapshot.displayData.indicatorGrid = .init(indicators: [indicator])
                let sheet = MeasurementDetailsViewController.createSheet(
                    from: indicator, for: fixture.snapshot, maximumSheetHeight: 640
                )
                sheet.overrideUserInterfaceStyle = style
                let host = hostView(sheet)
                defer { close(host) }
                let value = try XCTUnwrap(label("measurement.value", in: sheet.view))
                XCTAssertEqual(value.text, type == .aqi ? "75" : "123.45")
                if type != .txPower {
                    XCTAssertFalse(try XCTUnwrap(label("measurement.title", in: sheet.view)?.text).isEmpty)
                }
                XCTAssertNotNil(label("measurement.description", in: sheet.view)?.attributedText)
                XCTAssertLessThanOrEqual(sheet.preferredContentSize.height, 640)
                XCTAssertGreaterThan(sheet.preferredContentSize.height, 100)
                let graph = try XCTUnwrap(sheet.view.allDescendants.compactMap { $0 as? CardsGraphInternalView }.first)
                XCTAssertEqual(
                    graph.superview?.isHidden, type == .movementCounter || type == .measurementSequenceNumber)
                if type == .temperature {
                    let image = UIGraphicsImageRenderer(bounds: sheet.view.bounds).image { context in
                        sheet.view.layer.render(in: context.cgContext)
                    }
                    XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 2000)
                    let attachment = XCTAttachment(image: image)
                    attachment.name = style == .light ? "Measurement details light" : "Measurement details dark"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    func testAQIReconfigurationNeverDuplicatesCardsAndUndefinedReadingsHideThem() throws {
        let fixture = MeasurementFixture()
        var indicators = [
            makeIndicator(.init(type: .aqi), value: "80/100", quality: .good(80)),
            makeIndicator(.init(type: .co2), value: "750", quality: .good(750)),
            makeIndicator(.init(type: .pm25), value: "5", quality: .excellent(5)),
        ]
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: indicators)
        let sheet = MeasurementDetailsViewController.createSheet(
            from: indicators[0], for: fixture.snapshot, maximumSheetHeight: 700
        )
        let output = DetailsViewOutputSpy()
        sheet.output = output
        let host = hostView(sheet)
        defer { close(host) }
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(cards(sheet).count, 2)
        sheet.configure(measurementType: .aqi, value: "80", unit: "/100", quality: .good(80))
        XCTAssertEqual(cards(sheet).count, 2, "Refreshing AQI configuration must reuse two cards")
        indicators[0] = makeIndicator(.init(type: .aqi), value: "0/100", quality: .undefined(0))
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: indicators)
        sheet.updateMeasurements(with: fixture.snapshot.displayData)
        XCTAssertEqual(label("measurement.value", in: sheet.view)?.text, RuuviLocalization.na)
        XCTAssertTrue(cards(sheet).isEmpty)
        for quality: MeasurementQualityState in [.excellent(100), .fair(60), .poor(30), .veryPoor(10)] {
            indicators[0] = makeIndicator(.init(type: .aqi), value: "60/100", quality: quality)
            fixture.snapshot.displayData.indicatorGrid = .init(indicators: indicators)
            sheet.updateMeasurements(with: fixture.snapshot.displayData)
            XCTAssertEqual(cards(sheet).count, 2)
        }
        cards(sheet).first?.onTap?()
        XCTAssertEqual(output.selected?.type, .co2)
        XCTAssertEqual(label("measurement.value", in: sheet.view)?.text, "750")
        XCTAssertTrue(cards(sheet).isEmpty, "Selecting CO₂ replaces the AQI content")
    }

    func testHeaderMatchesTheExactUnitVariantAndReflectsAlertAvailability() throws {
        let fixture = MeasurementFixture()
        let celsius = makeIndicator(.init(type: .temperature, temperatureUnit: .celsius), value: "20")
        let fahrenheit = makeIndicator(.init(type: .temperature, temperatureUnit: .fahrenheit), value: "68")
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [celsius, fahrenheit])
        let sheet = MeasurementDetailsViewController.createSheet(
            from: fahrenheit, for: fixture.snapshot, maximumSheetHeight: 700
        )
        let host = hostView(sheet)
        defer { close(host) }
        sheet.updateMeasurements(with: nil)
        sheet.updateMeasurements(with: fixture.snapshot.displayData)
        XCTAssertEqual(label("measurement.value", in: sheet.view)?.text, "68")
        XCTAssertFalse(sheet.indicatorMatchesCurrentSelection(celsius))
        XCTAssertTrue(sheet.indicatorMatchesCurrentSelection(fahrenheit))
        fixture.snapshot.updateAlertConfig(
            for: .temperature,
            config: .init(
                isActive: true, isFiring: true, mutedTill: nil, lowerBound: 0, upperBound: 10
            ))
        fixture.snapshot.metadata.isAlertAvailable = true
        sheet.updateAlertStates()
        XCTAssertEqual(label("measurement.value", in: sheet.view)?.textColor, RuuviColor.orangeColor.color)
        fixture.snapshot.metadata.isAlertAvailable = false
        sheet.updateAlertStates()
        XCTAssertEqual(label("measurement.value", in: sheet.view)?.textColor, RuuviColor.dashboardIndicatorBig.color)
    }

    func testChartAcceptsHistoryLiveEntriesAndEmptyState() throws {
        let fixture = MeasurementFixture()
        let indicator = fixture.indicator(.init(type: .temperature))
        let sheet = MeasurementDetailsViewController.createSheet(
            from: indicator, for: fixture.snapshot, maximumSheetHeight: 700
        )
        let host = hostView(sheet)
        defer { close(host) }
        let graph = try XCTUnwrap(sheet.view.allDescendants.compactMap { $0 as? CardsGraphInternalView }.first)
        let now = Date().timeIntervalSince1970
        let entries = [ChartDataEntry(x: now - 60, y: 20), ChartDataEntry(x: now, y: 22)]
        let dataSet = RuuviGraphDataSetFactory.simpleGraphDataSet(
            upperAlertValue: 25, entries: entries, lowerAlertValue: 10, showAlertRangeInGraph: true
        )
        sheet.setChartData(
            .init(
                upperAlertValue: 25, variant: indicator.variant, chartData: LineChartData(dataSet: dataSet),
                lowerAlertValue: 10),
            settings: fixture.settings, displayType: .temperature, unit: "°C", measurementService: fixture.measurement
        )
        XCTAssertEqual(graph.data?.entryCount, 2)
        XCTAssertFalse(graph.isHidden)
        XCTAssertEqual(graph.lowerAlertValue, 10)
        XCTAssertEqual(graph.upperAlertValue, 25)
        sheet.updateChartData([ChartDataEntry(x: now + 60, y: 23)], showAlertRangeInGraph: false)
        XCTAssertEqual(graph.data?.entryCount, 3)
        sheet.updateChartData(
            [
                ChartDataEntry(x: now + 60, y: 23), ChartDataEntry(x: now + 120, y: .nan),
                ChartDataEntry(x: .infinity, y: 24), ChartDataEntry(x: now - 60, y: 20),
            ], showAlertRangeInGraph: false)
        XCTAssertEqual(graph.data?.entryCount, 3, "Duplicate and nonfinite readings must not corrupt the chart")
        sheet.setNoDataLabelVisibility(show: true)
        XCTAssertTrue(graph.isHidden)
        sheet.setNoDataLabelVisibility(show: false)
        XCTAssertFalse(graph.isHidden)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func makeIndicator(
        _ variant: MeasurementDisplayVariant, value: String, quality: MeasurementQualityState? = nil
    ) -> RuuviTagCardSnapshotIndicatorData {
        .init(
            variant: variant, value: value, unit: "unit", isProminent: true, showSubscript: false,
            tintColor: nil, qualityState: quality)
    }
    private func hostView(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 700))
        window.rootViewController = controller
        controller.loadViewIfNeeded()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        return window
    }
    private func close(_ window: UIWindow) {
        window.rootViewController?.beginAppearanceTransition(false, animated: false)
        window.rootViewController?.endAppearanceTransition()
        window.rootViewController = nil
    }
    private func cards(_ controller: UIViewController) -> [CardsMeasurementIndicatorView] {
        controller.view.allDescendants.compactMap { $0 as? CardsMeasurementIndicatorView }
    }
    private func label(_ id: String, in view: UIView) -> UILabel? {
        view.allDescendants.first { $0.accessibilityIdentifier == id } as? UILabel
    }
}

private final class DetailsViewOutputSpy: MeasurementDetailsViewOutput {
    var loads = 0
    var graphTaps = 0
    var selected: RuuviTagCardSnapshotIndicatorData?
    func viewDidLoad() { loads += 1 }
    func didTapGraph() { graphTaps += 1 }
    func didTapMeasurement(_ measurement: RuuviTagCardSnapshotIndicatorData) { selected = measurement }
}

extension UIView {
    var allDescendants: [UIView] { subviews.flatMap { [$0] + $0.allDescendants } }
}
