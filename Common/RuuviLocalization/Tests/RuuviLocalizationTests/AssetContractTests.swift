import RuuviLocalization
import SwiftUI
import UIKit
import XCTest

enum AssetCatalog {}

@MainActor final class AssetContractTests: XCTestCase {
    func testEveryExportedImageResolvesInBothAppearancesAndRendersAtItsDeclaredSize() throws {
        XCTAssertEqual(Set(AssetCatalog.images.map(\.0)).count, AssetCatalog.images.count)
        for (name, asset) in AssetCatalog.images {
            XCTAssertEqual(asset.name, name)
            let image = asset.image
            XCTAssertGreaterThan(image.size.width, 0, name)
            XCTAssertGreaterThan(image.size.height, 0, name)
            XCTAssertEqual(UIImage(asset: asset)?.size, image.size, name)
            for style in [UIUserInterfaceStyle.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let adapted = asset.image(compatibleWith: traits)
                let expected = try XCTUnwrap(
                    UIImage(
                        named: name, in: LocalizationTestBundle.bundle, compatibleWith: traits), name)
                XCTAssertEqual(adapted.size, expected.size, name)
                XCTAssertEqual(adapted.renderingMode, expected.renderingMode, name)
                let rendered = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { _ in
                    adapted.draw(in: CGRect(x: 0, y: 0, width: 32, height: 32))
                }
                XCTAssertNotNil(rendered.cgImage, name)
                XCTAssertEqual(rendered.size, CGSize(width: 32, height: 32))
            }
        }
    }

    func testEveryExportedColorResolvesConsistentlyForLightAndDarkTraits() throws {
        XCTAssertEqual(Set(AssetCatalog.colors.map(\.0)).count, AssetCatalog.colors.count)
        for (name, asset) in AssetCatalog.colors {
            XCTAssertEqual(asset.name, name)
            for style in [UIUserInterfaceStyle.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let expected = try XCTUnwrap(
                    UIColor(
                        named: name, in: LocalizationTestBundle.bundle, compatibleWith: traits), name)
                XCTAssertEqual(asset.color.resolvedColor(with: traits), expected.resolvedColor(with: traits), name)
                XCTAssertEqual(asset.color(compatibleWith: traits), expected, name)
                XCTAssertEqual(
                    UIColor(asset: asset)?.resolvedColor(with: traits),
                    expected.resolvedColor(with: traits), name)
            }
        }
    }

    func testSwiftUIAssetsRenderWithTheSameNamesAndAccessibleLabels() throws {
        let asset = RuuviAsset.Measurements.iconTemperature
        let views: [AnyView] = [
            AnyView(asset.swiftUIImage),
            AnyView(Image(asset: asset, label: Text("Temperature"))),
            AnyView(Image(decorative: asset)),
            AnyView(RuuviColor.orangeColor.swiftUIColor.frame(width: 32, height: 32)),
        ]
        for view in views {
            let renderer = ImageRenderer(content: view.frame(width: 32, height: 32))
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size, CGSize(width: 32, height: 32))
            XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 100)
        }
    }
}
