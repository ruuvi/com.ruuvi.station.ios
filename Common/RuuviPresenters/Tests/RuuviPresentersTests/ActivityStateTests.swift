import SwiftUI
import UIKit
import XCTest
@testable import RuuviPresenters

@MainActor final class ActivityStateTests: XCTestCase {
    func testStateEqualityIncludesMessagesAndDistinguishesAllStates() {
        let states: [ActivityPresenterState] = [
            .loading(message: nil), .loading(message: "Loading"),
            .success(message: nil), .success(message: "Saved"),
            .failed(message: nil), .failed(message: "Failed"), .dismiss,
        ]
        for (leftIndex, left) in states.enumerated() {
            for (rightIndex, right) in states.enumerated() {
                XCTAssertEqual(left == right, leftIndex == rightIndex)
            }
        }
    }

    func testEveryVisibleStateRendersWithAndWithoutCustomTextAtEachPosition() throws {
        let holder = ActivityPresenterStateHolder()
        let provider = ActivityPresenterViewProvider(stateHolder: holder)
        let controller = provider.makeViewController()
        controller.loadViewIfNeeded()
        for position: ActivityPresenterPosition in [.top, .center, .bottom] {
            provider.updatePosition(position)
            XCTAssertEqual(holder.position, position)
            for state: ActivityPresenterState in [
                .loading(message: nil), .loading(message: "Loading history"),
                .success(message: nil), .success(message: "Saved"),
                .failed(message: nil), .failed(message: "Could not save"), .dismiss,
            ] {
                provider.updateState(state)
                XCTAssertEqual(holder.state, state)
                let view = ActivityPresenterView().environmentObject(holder).frame(width: 300, height: 120)
                let image = try XCTUnwrap(ImageRenderer(content: view).uiImage)
                XCTAssertEqual(image.size, CGSize(width: 300, height: 120))
            }
        }
    }
}
