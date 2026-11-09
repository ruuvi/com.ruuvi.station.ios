import RuuviLocalization
import SwiftUI
import UIKit
import XCTest

/// The size-class mapping and the grid fitting that replace the device-type and orientation checks.
/// The device tables are today's full-screen sizes: the fitted counts must equal what iPhone and iPad
/// showed before the app became resizable.
final class RuuviLayoutClassTests: XCTestCase {
    func testSizeClassMapping() {
        XCTAssertEqual(RuuviLayoutClass(horizontal: .regular, vertical: .regular), .regular)
        XCTAssertEqual(RuuviLayoutClass(horizontal: .compact, vertical: .regular), .compactWidth)
        XCTAssertEqual(RuuviLayoutClass(horizontal: .compact, vertical: .compact), .compactHeight)
        // iPhone Pro Max in landscape keeps the iPhone landscape layout.
        XCTAssertEqual(RuuviLayoutClass(horizontal: .regular, vertical: .compact), .compactHeight)
        // Not in a window yet: the iPhone portrait layout until real traits arrive.
        XCTAssertEqual(RuuviLayoutClass(horizontal: .unspecified, vertical: .unspecified), .compactWidth)
        XCTAssertEqual(RuuviLayoutClass(horizontal: .regular, vertical: .unspecified), .compactWidth)
    }

    func testSwiftUISizeClassMapping() {
        let regular: UserInterfaceSizeClass? = .regular
        let compact: UserInterfaceSizeClass? = .compact
        XCTAssertEqual(RuuviLayoutClass(horizontal: regular, vertical: regular), .regular)
        XCTAssertEqual(RuuviLayoutClass(horizontal: compact, vertical: regular), .compactWidth)
        XCTAssertEqual(RuuviLayoutClass(horizontal: regular, vertical: compact), .compactHeight)
        XCTAssertEqual(RuuviLayoutClass(horizontal: nil, vertical: nil), .compactWidth)
    }

    func testTraitCollectionMapping() {
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(horizontalSizeClass: .regular),
            UITraitCollection(verticalSizeClass: .regular),
        ])
        XCTAssertEqual(traits.ruuviLayoutClass, .regular)
    }

    func testFitPicksFewestColumnsWithinTheMaximum() {
        XCTAssertEqual(RuuviGridFit.columns(in: 1000, counts: [1, 2, 3], maximumColumnWidth: 400), 3)
        XCTAssertEqual(RuuviGridFit.columns(in: 700, counts: [1, 2, 3], maximumColumnWidth: 400), 2)
        XCTAssertEqual(RuuviGridFit.columns(in: 300, counts: [1, 2, 3], maximumColumnWidth: 400), 1)
        // None fits: the largest count.
        XCTAssertEqual(RuuviGridFit.columns(in: 5000, counts: [1, 2, 3], maximumColumnWidth: 400), 3)
        // No width yet: the smallest count.
        XCTAssertEqual(RuuviGridFit.columns(in: 0, counts: [2, 3], maximumColumnWidth: 400), 2)
    }

    func testFitRespectsTheMinimum() {
        // 3 columns would be 90pt wide; 2 are 135pt, above the 100pt minimum.
        XCTAssertEqual(
            RuuviGridFit.columns(in: 270, counts: [2, 3], minimumColumnWidth: 100, maximumColumnWidth: 100),
            2
        )
        // Even the smallest count is too narrow: keep the smallest count.
        XCTAssertEqual(
            RuuviGridFit.columns(in: 150, counts: [2, 3], minimumColumnWidth: 100, maximumColumnWidth: 100),
            2
        )
    }

    func testColumnWidth() {
        XCTAssertEqual(RuuviGridFit.columnWidth(in: 1032, columns: 3, spacing: 6, padding: 120), 300)
    }

    // MARK: - Today's counts on full-screen devices

    private let iPadPortraitWidths: [CGFloat] = [744, 768, 810, 820, 834, 1024, 1032]
    private let iPadLandscapeWidths: [CGFloat] = [1080, 1133, 1180, 1194, 1210, 1366, 1376]

    /// Dashboard: the collection view is the safe-area width minus 12pt; 8pt section insets, 8pt gaps.
    private func dashboardColumns(safeAreaWidth: CGFloat) -> Int {
        RuuviGridFit.columns(
            in: safeAreaWidth - 12,
            counts: [1, 2, 3],
            spacing: 8,
            padding: { _ in 16 },
            maximumColumnWidth: 516
        )
    }

    func testDashboardKeepsTodaysColumnCounts() {
        for width: CGFloat in [320, 375, 390, 393, 402, 414, 428, 430, 440] {
            XCTAssertEqual(dashboardColumns(safeAreaWidth: width), 1, "iPhone portrait \(width)")
        }
        // iPhone landscape safe-area widths (screen width minus the side insets).
        for width: CGFloat in [568, 667, 736, 724, 712, 750, 734, 750, 800, 832, 814, 832] {
            XCTAssertEqual(dashboardColumns(safeAreaWidth: width), 2, "iPhone landscape \(width)")
        }
        for width in iPadPortraitWidths {
            XCTAssertEqual(dashboardColumns(safeAreaWidth: width), 2, "iPad portrait \(width)")
        }
        for width in iPadLandscapeWidths {
            XCTAssertEqual(dashboardColumns(safeAreaWidth: width), 3, "iPad landscape \(width)")
        }
    }

    func testMeasurementGridKeepsTodaysIPadColumnCounts() {
        func columns(_ width: CGFloat) -> Int {
            RuuviGridFit.columns(
                in: width,
                counts: [3, 4],
                spacing: 6,
                padding: { $0 >= 4 ? 160 : 120 },
                minimumColumnWidth: 100,
                maximumColumnWidth: 308
            )
        }
        for width in iPadPortraitWidths {
            XCTAssertEqual(columns(width), 3, "iPad portrait \(width)")
        }
        for width in iPadLandscapeWidths {
            XCTAssertEqual(columns(width), 4, "iPad landscape \(width)")
        }
    }

    func testBackgroundSelectionKeepsTodaysIPadCounts() {
        /// The collection view is the safe-area width minus 12pt on each side.
        func columns(_ width: CGFloat) -> Int {
            RuuviGridFit.columns(in: width - 24, counts: [5, 8], maximumColumnWidth: 206)
        }
        for width in iPadPortraitWidths {
            XCTAssertEqual(columns(width), 5, "iPad portrait \(width)")
        }
        for width in iPadLandscapeWidths {
            XCTAssertEqual(columns(width), 8, "iPad landscape \(width)")
        }
    }
}
