import SwiftUI
import UIKit
import XCTest
@testable import RuuviLocalization

@MainActor final class FontContractTests: XCTestCase {
    func testEveryFontWeightLoadsTheBundledFaceAndPreservesRequestedSize() {
        for weight in RuuviFonts.MulishWeight.allCases {
            assertFont(RuuviFonts.mulish(weight, size: 19), family: "Mulish", style: weight.rawValue)
            assertFont(UIFont.mulish(weight, size: 19), family: "Mulish", style: weight.rawValue)
            assertFont(RuuviFonts.mulish(weight, size: 19, for: .body), family: "Mulish", style: weight.rawValue)
            XCTAssertEqual(weight.fontAsset.family, "Mulish")
            XCTAssertEqual(weight.fontAsset.style, weight.rawValue)
        }
        for weight in RuuviFonts.MontserratWeight.allCases {
            assertFont(RuuviFonts.montserrat(weight, size: 19), family: "Montserrat", style: weight.rawValue)
            assertFont(UIFont.montserrat(weight, size: 19), family: "Montserrat", style: weight.rawValue)
            assertFont(
                RuuviFonts.montserrat(weight, size: 19, for: .body), family: "Montserrat", style: weight.rawValue)
            XCTAssertEqual(weight.fontAsset.family, "Montserrat")
            XCTAssertEqual(weight.fontAsset.style, weight.rawValue)
        }
        for weight in RuuviFonts.OswaldWeight.allCases {
            assertFont(RuuviFonts.oswald(weight, size: 19), family: "Oswald", style: weight.rawValue)
            assertFont(UIFont.oswald(weight, size: 19), family: "Oswald", style: weight.rawValue)
            assertFont(RuuviFonts.oswald(weight, size: 19, for: .body), family: "Oswald", style: weight.rawValue)
            XCTAssertEqual(weight.fontAsset.family, "Oswald")
            XCTAssertEqual(weight.fontAsset.style, weight.rawValue)
        }
    }

    func testTypographyKeepsItsHierarchyAndUsesTheCustomFamily() {
        let groups: [[UIFont]] = [
            [.ruuviHeadlineLarge(), .ruuviHeadlineMedium(), .ruuviHeadlineSmall(), .ruuviHeadlineTiny()],
            [.ruuviBodyLarge(), .ruuviBodyMedium(), .ruuviBodySmall()],
            [.ruuviCaptionLarge(), .ruuviCaptionSmall()],
            [.ruuviButtonLarge(), .ruuviButtonMedium(), .ruuviButtonSmall()],
            [.ruuviLargeTitle(), .ruuviTitle1(), .ruuviTitle2(), .ruuviTitle3()],
            [
                .ruuviHeadline(), .ruuviCallout(), .ruuviSubheadline(), .ruuviFootnote(), .ruuviCaption1(),
                .ruuviCaption2(),
            ],
        ]
        for group in groups {
            for font in group {
                XCTAssertEqual(font.familyName, "Mulish")
                XCTAssertGreaterThan(font.pointSize, 8)
            }
            for pair in zip(group, group.dropFirst()) {
                XCTAssertGreaterThan(pair.0.pointSize, pair.1.pointSize)
            }
        }
        XCTAssertEqual(UIFont.ruuviBody().fontName, "Mulish-Regular")
        XCTAssertEqual(UIFont.ruuviSubheadlineBold().fontName, "Mulish-Bold")
        XCTAssertEqual(UIFont.ruuviSubheadlineBold().pointSize, UIFont.ruuviSubheadline().pointSize)
    }

    func testDynamicStylesMapToTheirUIKitAndSwiftUITextStyles() throws {
        let cases: [(RuuviFonts.DynamicType, UIFont.TextStyle, SwiftUI.Font.TextStyle)] = [
            (.largeTitle(), .largeTitle, .largeTitle), (.title1(), .title1, .title),
            (.title2(), .title2, .title2), (.title3(), .title3, .title3),
            (.headline(), .headline, .headline), (.subheadline(), .subheadline, .subheadline),
            (.body(), .body, .body), (.callout(), .callout, .callout),
            (.footnote(), .footnote, .footnote), (.caption1(), .caption1, .caption),
            (.caption2(), .caption2, .caption2),
        ]
        for (style, uiStyle, swiftUIStyle) in cases {
            XCTAssertEqual(style.textStyle, uiStyle)
            XCTAssertEqual(style.swiftUITextStyle, swiftUIStyle)
            XCTAssertEqual(style.scaledFont().fontName, style.fontAsset.name)
            let renderer = ImageRenderer(content: Text("Ruuvi 🌡️ 123").font(style.swiftUIFont()))
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.width, 30)
            XCTAssertGreaterThan(image.size.height, 5)
        }
        let missing = FontAsset(name: "MissingFontForFallbackTest", family: "Missing", style: "Regular")
        XCTAssertEqual(missing.font(size: 19).fontName, UIFont.systemFont(ofSize: 19).fontName)
        XCTAssertEqual(missing.scaledFont(for: .body), UIFont.preferredFont(forTextStyle: .body))
        XCTAssertEqual(RuuviFonts.Mulish.regular.scaledFont(for: .body).fontName, "Mulish-Regular")
    }

    func testSwiftUIFontConveniencesRenderEveryFamilyAndWeight() throws {
        var fonts: [SwiftUI.Font] = []
        for weight in RuuviFonts.MulishWeight.allCases {
            fonts += [
                .mulish(weight, size: 19), .mulish(weight, size: 19, relativeTo: .body),
                RuuviFonts.mulishSwiftUI(weight, size: 19),
                RuuviFonts.mulishSwiftUI(weight, size: 19, relativeTo: .body),
            ]
        }
        for weight in RuuviFonts.MontserratWeight.allCases {
            fonts += [
                .montserrat(weight, size: 19), .montserrat(weight, size: 19, relativeTo: .body),
                RuuviFonts.montserratSwiftUI(weight, size: 19),
                RuuviFonts.montserratSwiftUI(weight, size: 19, relativeTo: .body),
            ]
        }
        for weight in RuuviFonts.OswaldWeight.allCases {
            fonts += [
                .oswald(weight, size: 19), .oswald(weight, size: 19, relativeTo: .body),
                RuuviFonts.oswaldSwiftUI(weight, size: 19),
                RuuviFonts.oswaldSwiftUI(weight, size: 19, relativeTo: .body),
            ]
        }
        for font in fonts {
            let image = try XCTUnwrap(ImageRenderer(content: Text("Abc 123").font(font)).uiImage)
            XCTAssertGreaterThan(image.size.width, 20)
            XCTAssertGreaterThan(image.size.height, 10)
        }
    }

    func testSwiftUITypographyPreservesHierarchyAndEverySemanticStyleRenders() throws {
        let groups: [[SwiftUI.Font]] = [
            [.ruuviHeadlineLarge(), .ruuviHeadlineMedium(), .ruuviHeadlineSmall()],
            [.ruuviBodyLarge(), .ruuviBodyMedium(), .ruuviBodySmall()],
            [.ruuviCaptionLarge(), .ruuviCaptionSmall()],
            [.ruuviButtonLarge(), .ruuviButtonMedium(), .ruuviButtonSmall()],
            [.ruuviLargeTitle(), .ruuviTitle1(), .ruuviTitle2(), .ruuviTitle3()],
            [
                .ruuviHeadline(), .ruuviCallout(), .ruuviSubheadline(), .ruuviFootnote(), .ruuviCaption1(),
                .ruuviCaption2(),
            ],
        ]
        for group in groups {
            let sizes = try group.map { font in
                try XCTUnwrap(ImageRenderer(content: Text("Ruuvi 123").font(font)).uiImage).size
            }
            XCTAssertTrue(sizes.allSatisfy { $0.width > 20 && $0.height > 5 })
            for pair in zip(sizes, sizes.dropFirst()) { XCTAssertGreaterThan(pair.0.height, pair.1.height) }
        }
        let body = try XCTUnwrap(ImageRenderer(content: Text("Ruuvi").font(SwiftUI.Font.ruuviBody())).uiImage)
        XCTAssertGreaterThan(body.size.height, 10)
        let asset = RuuviFonts.Mulish.regular
        XCTAssertEqual(try XCTUnwrap(UIFont(asset: asset, size: 19)).fontName, "Mulish-Regular")
        for font in [SwiftUI.Font.ruuvi(asset, size: 19), asset.swiftUIFont(size: 19, relativeTo: .body)] {
            let image = try XCTUnwrap(ImageRenderer(content: Text("Ruuvi").font(font)).uiImage)
            XCTAssertGreaterThan(image.size.height, 10)
        }
    }

    private func assertFont(
        _ font: UIFont, family: String, style: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(font.fontName, family + "-" + style, file: file, line: line)
        XCTAssertEqual(font.pointSize, 19, accuracy: 0.01, file: file, line: line)
    }
}
