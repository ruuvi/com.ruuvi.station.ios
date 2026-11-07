import UIKit
import XCTest
@testable import station

@MainActor final class LinkTextInteractionTests: XCTestCase {
    func testReconfiguringALinkKeepsOneGestureAndOnlyRoutesTheCurrentURL() throws {
        let view = RuuviLinkTextView(fullTextString: "Read help", linkString: "help", link: "https://ruuvi.com/old")
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 140)
        let delegate = TextLinkDelegate()
        view.linkDelegate = delegate
        let initialGestures = view.gestureRecognizers?.count
        for _ in 0..<3 {
            view.setUpComponents(fullTextString: "Updated help", linkString: "help", link: "https://ruuvi.com/new")
        }
        XCTAssertEqual(
            view.gestureRecognizers?.count, initialGestures,
            "Rebinding a reused view must not register another handler for the same tap")
        sendTap(view, at: linkRect(view, word: "help").center)
        XCTAssertEqual(delegate.urls, ["https://ruuvi.com/new"])
    }

    func testWrappedUnicodeLinksRespectTextInsetsAndDoNotOpenFromBlankSpace() throws {
        let view = RuuviLinkTextView(
            fullTextString: "Room 🌿 e\u{301}\nRead help", linkString: "help", link: "https://ruuvi.com/help",
            fontSize: 18)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
        view.textContainerInset = UIEdgeInsets(top: 30, left: 24, bottom: 10, right: 12)
        let delegate = TextLinkDelegate()
        view.linkDelegate = delegate
        let link = linkRect(view, word: "help")
        sendTap(view, at: link.center)
        XCTAssertEqual(delegate.urls, ["https://ruuvi.com/help"])
        delegate.urls.removeAll()
        for point in [
            CGPoint(x: view.bounds.maxX - 1, y: link.midY),
            CGPoint(x: link.midX, y: link.maxY + 30), linkRect(view, word: "Room").center, .zero,
        ] {
            sendTap(view, at: point)
            XCTAssertTrue(delegate.urls.isEmpty, "Only the link under the finger should open: \(point)")
            delegate.urls.removeAll()
        }
    }

    private func linkRect(_ view: UITextView, word: String) -> CGRect {
        view.layoutIfNeeded()
        view.layoutManager.ensureLayout(for: view.textContainer)
        let range = (view.text as NSString).range(of: word)
        let glyphs = view.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return view.layoutManager.boundingRect(forGlyphRange: glyphs, in: view.textContainer)
            .offsetBy(
                dx: view.textContainerInset.left - view.contentOffset.x,
                dy: view.textContainerInset.top - view.contentOffset.y)
    }
    private func sendTap(_ view: RuuviLinkTextView, at point: CGPoint) {
        let action = NSSelectorFromString("handleTapWithGestureRecognizer:")
        XCTAssertTrue(view.responds(to: action))
        guard view.responds(to: action) else { return }
        _ = view.perform(action, with: TextLinkTap(point: point))
    }
}
private final class TextLinkTap: UITapGestureRecognizer {
    let point: CGPoint
    init(point: CGPoint) { self.point = point; super.init(target: nil, action: nil) }
    override var state: UIGestureRecognizer.State {
        get { .ended }
        set {}
    }
    override func location(in view: UIView?) -> CGPoint { point }
}
private final class TextLinkDelegate: NSObject, RuuviLinkTextViewDelegate {
    var urls = [String]()
    func didTapLink(url: String) { urls.append(url) }
}
private extension CGRect { var center: CGPoint { CGPoint(x: midX, y: midY) } }
