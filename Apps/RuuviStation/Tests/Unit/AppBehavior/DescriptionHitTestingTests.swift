import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class DescriptionHitTestingTests: XCTestCase {
    func testWrappedUnicodeDescriptionRoutesOnlyTheLinkUnderTheFinger() async throws {
        let fixture = try await DescriptionHitFixture(text: "Room 🌿 e\u{301}\nRead help")
        defer { fixture.close() }
        let text = fixture.text.string as NSString
        let linkRange = text.range(of: "help")
        fixture.sendTap(at: fixture.rect(for: linkRange).center)
        XCTAssertEqual(fixture.links, ["https://ruuvi.com/help"])
        fixture.links.removeAll()
        fixture.sendTap(at: fixture.rect(for: text.range(of: "Room")).center)
        XCTAssertTrue(fixture.links.isEmpty)
    }

    func testWhitespaceAndLocationsOutsideTheLabelDoNotActivateTheNearestLink() async throws {
        let fixture = try await DescriptionHitFixture(text: "Read help")
        defer { fixture.close() }
        let link = fixture.rect(for: (fixture.text.string as NSString).range(of: "help"))
        XCTAssertLessThan(link.maxX + 20, fixture.label.bounds.maxX)
        for point in [
            CGPoint(x: fixture.label.bounds.maxX - 1, y: link.midY),
            CGPoint(x: link.midX, y: fixture.label.bounds.maxY + 20),
            CGPoint(x: -20, y: link.midY),
        ] {
            fixture.sendTap(at: point)
            XCTAssertTrue(fixture.links.isEmpty, "A tap outside link glyphs must not open a nearby link: \(point)")
            fixture.links.removeAll()
        }
    }

    func testCancelledGestureAndAnEmptyDescriptionNeverNavigate() async throws {
        let fixture = try await DescriptionHitFixture(text: "Read help")
        defer { fixture.close() }
        let rect = fixture.rect(for: (fixture.text.string as NSString).range(of: "help"))
        fixture.sendTap(at: rect.center, state: .cancelled)
        XCTAssertTrue(fixture.links.isEmpty)
        fixture.label.attributedText = NSAttributedString(string: "")
        fixture.sendTap(at: .zero)
        XCTAssertTrue(fixture.links.isEmpty)
    }
}

@MainActor private final class DescriptionHitFixture {
    let measurements = MeasurementFixture()
    let sheet: MeasurementDetailsViewController
    let host: AppViewHost
    let text: NSAttributedString
    let label: UILabel
    var links = [String]()
    init(text value: String) async throws {
        sheet = MeasurementDetailsViewController.createSheet(
            from: measurements.indicator(.init(type: .temperature)), for: measurements.snapshot, maximumSheetHeight: 800
        )
        host = try AppViewHost(sheet)
        let attributed = NSMutableAttributedString(string: value, attributes: [.font: UIFont.systemFont(ofSize: 18)])
        attributed.addAttribute(
            .init("CustomLinkURL"), value: "https://ruuvi.com/help", range: (value as NSString).range(of: "help"))
        text = attributed
        label = try XCTUnwrap(
            sheet.view.allDescendants.compactMap { $0 as? UILabel }.first {
                $0.accessibilityIdentifier == "measurement.description"
            })
        sheet.configure(measurementType: .temperature, value: "20", description: attributed) { [weak self] url in
            self?.links.append(url)
        }
        await flushAppBindings()
        sheet.view.layoutIfNeeded()
        XCTAssertGreaterThan(label.bounds.width, 200)
    }
    func rect(for range: NSRange) -> CGRect {
        let storage = NSTextStorage(attributedString: text)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: label.bounds.size)
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = label.numberOfLines
        container.lineBreakMode = label.lineBreakMode
        storage.addLayoutManager(manager); manager.addTextContainer(container)
        return manager.boundingRect(
            forGlyphRange: manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: container)
    }
    func sendTap(at point: CGPoint, state: UIGestureRecognizer.State = .ended) {
        // Exercise the app's Objective-C gesture action with UIKit-style event coordinates.
        let gesture = DescriptionTap(point: point, state: state)
        _ = sheet.perform(NSSelectorFromString("handleDescriptionTap:"), with: gesture)
    }
    func close() { host.close(); measurements.cleanup() }
}
private final class DescriptionTap: UITapGestureRecognizer {
    private let point: CGPoint
    private let eventState: UIGestureRecognizer.State
    init(point: CGPoint, state: UIGestureRecognizer.State) {
        self.point = point; eventState = state
        super.init(target: nil, action: nil)
    }
    override var state: UIGestureRecognizer.State {
        get { eventState }
        set {}
    }
    override func location(in view: UIView?) -> CGPoint { point }
}
private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
