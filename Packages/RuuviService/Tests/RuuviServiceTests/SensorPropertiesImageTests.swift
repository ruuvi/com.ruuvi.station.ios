import Foundation
import RuuviOntology
import UIKit
import XCTest
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviServiceSensorProperties
#endif

@MainActor final class SensorPropertiesImageTests: XCTestCase {
    func testImageLookupPrefersMacCacheThenLocalIdentityThenMacGeneration() async throws {
        let fixture = try PropertiesFixture()
        let sensor = fixture.sensor.with(luid: "local-image".luid)
        let mac = sensor.macId!.value
        fixture.images.cached[mac] = fixture.images.image
        let cached = try await fixture.service.getImage(for: sensor)
        XCTAssertTrue(cached === fixture.images.image)
        XCTAssertTrue(fixture.images.requests.isEmpty)
        fixture.images.cached.removeAll()
        fixture.images.generated[sensor.luid!.value] = fixture.images.image
        let local = try await fixture.service.getImage(for: sensor)
        XCTAssertTrue(local === fixture.images.image)
        XCTAssertEqual(fixture.images.requests.map(\.0), [sensor.luid!.value])
        fixture.images.generated = [mac: fixture.images.image]
        fixture.images.requests.removeAll()
        let generated = try await fixture.service.getImage(for: sensor)
        XCTAssertTrue(generated === fixture.images.image)
        XCTAssertEqual(fixture.images.requests.map(\.0), [sensor.luid!.value, mac])
    }

    func testImageGenerationSelectsDeviceTypeForAirAndTagAndSupportsLocalOnlySensors() async throws {
        let fixture = try PropertiesFixture()
        for version in [3, 5, 6, 225] {
            var sensor = fixture.sensor
            sensor.version = version
            sensor.luid = "local-image".luid
            sensor.macId = nil
            fixture.images.generated[sensor.luid!.value] = fixture.images.image
            _ = try await fixture.service.getImage(for: sensor)
            XCTAssertEqual(fixture.images.requests.last?.1, version == 6 || version == 225 ? .ruuviAir : .ruuviTag)
        }
    }

    func testMissingIdentityOrImageGenerationFailsWithTheSpecificError() async throws {
        let fixture = try PropertiesFixture()
        for identity in [0, 1, 2] {
            var sensor = fixture.sensor
            sensor.luid = identity == 1 ? "local-image".luid : nil
            sensor.macId = identity == 2 ? fixture.sensor.macId : nil
            do { _ = try await fixture.service.getImage(for: sensor); XCTFail("Missing image succeeded") } catch {
                if identity == 0 {
                    guard case .bothLuidAndMacAreNil = error else { return XCTFail("Unexpected \(error)") }
                } else {
                    guard case .failedToFindOrGenerateBackgroundImage = error else {
                        return XCTFail("Unexpected \(error)")
                    }
                }
            }
        }
        fixture.images.missingDefault = true
        do {
            _ = try await fixture.service.setNextDefaultBackground(for: fixture.sensor);
            XCTFail("Missing default succeeded")
        } catch {
            guard case .failedToFindOrGenerateBackgroundImage = error else { return XCTFail("Unexpected \(error)") }
        }
    }

    func testImageUploadStoresLocallyReportsProgressAndClearsTheProgressOnSuccess() async throws {
        let fixture = try PropertiesFixture()
        _ = try await fixture.pool.create(fixture.sensor)
        var received = [Double]()
        defer { fixture.cloud.onUpload = nil }
        fixture.cloud.onUpload = { request in
            XCTAssertGreaterThan(request.data.count, 0)
            XCTAssertEqual(request.mimeType, .jpg)
            XCTAssertEqual(request.macId.value, fixture.sensor.macId?.value)
            request.progress?(request.macId, 0.5); request.progress?(request.macId, 1)
            return URL(string: "https://example.com/image.jpg")!
        }
        let url = try await fixture.service.set(
            image: fixture.images.image, for: fixture.sensor,
            progress: { _, value in received.append(value) }, maxSize: CGSize(width: 8, height: 8),
            compressionQuality: 0.7)
        XCTAssertEqual(url, fixture.images.url)
        XCTAssertEqual(fixture.images.writes.first?.0, fixture.sensor.macId?.value)
        XCTAssertEqual(fixture.images.writes.first?.1, 0.7)
        XCTAssertEqual(received, [0.5, 1])
        XCTAssertEqual(fixture.images.progress.map(\.1), [0, 0.5, 1])
        XCTAssertEqual(fixture.images.deletedProgress, [fixture.sensor.macId!.value])
        let stored = try await fixture.storage.readOne(fixture.sensor.id)
        XCTAssertNotNil(stored.lastUpdated)
    }

    func testCloudUploadFailureKeepsTheLocalImageAndRemovesProgress() async throws {
        let fixture = try PropertiesFixture()
        _ = try await fixture.pool.create(fixture.sensor)
        do {
            _ = try await fixture.service.set(
                image: fixture.images.image, for: fixture.sensor,
                progress: nil, maxSize: CGSize(width: 8, height: 8), compressionQuality: 0.8)
            XCTFail("Offline cloud upload succeeded")
        } catch {
            guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertEqual(fixture.images.writes.count, 1)
        XCTAssertEqual(fixture.images.deletedProgress, [fixture.sensor.macId!.value])
    }

    func testLocalStorageFailureAndInvalidImageStopBeforeUploading() async throws {
        let fixture = try PropertiesFixture()
        fixture.images.localFailure = .failedToGetJpegRepresentation
        for image in [UIImage(), fixture.images.image] {
            do {
                _ = try await fixture.service.set(
                    image: image, for: fixture.sensor,
                    progress: nil, maxSize: CGSize(width: 8, height: 8), compressionQuality: 1)
                XCTFail("Invalid image operation succeeded")
            } catch {
                if image === fixture.images.image {
                    guard case .ruuviLocal(.failedToGetJpegRepresentation) = error else {
                        return XCTFail("Unexpected \(error)")
                    }
                } else {
                    guard case .failedToGetJpegRepresentation = error else { return XCTFail("Unexpected \(error)") }
                }
            }
        }
        XCTAssertEqual(fixture.images.writes.count, 1)
        XCTAssertTrue(fixture.images.progress.isEmpty)
    }

    func testLocalImageWriteDoesNotUploadAndRemovalInvalidatesBothIdentities() async throws {
        let fixture = try PropertiesFixture()
        var sensor = fixture.sensor
        sensor.luid = "local-image".luid
        sensor.isCloudSensor = false
        sensor.isClaimed = false
        _ = try await fixture.pool.create(sensor)
        let url = try await fixture.service.set(
            image: fixture.images.image, for: sensor,
            progress: nil, maxSize: CGSize(width: 8, height: 8), compressionQuality: 1)
        XCTAssertEqual(url, fixture.images.url)
        XCTAssertTrue(fixture.images.progress.isEmpty)
        fixture.service.removeImage(for: sensor)
        XCTAssertEqual(fixture.images.deleted, [sensor.macId!.value, sensor.luid!.value])
        XCTAssertEqual(fixture.images.invalidated, [sensor.id])
    }
}
