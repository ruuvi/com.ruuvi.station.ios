import BTKit
import Foundation
import RuuviCore
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviUser
import UIKit
#if SWIFT_PACKAGE
    import RuuviServiceSensorProperties
    import RuuviServiceOwnership
#endif

@MainActor final class OwnershipServiceFixture {
    let data: CloudSyncFixture
    let images = PropertiesImagesSpy()
    let user = OwnershipServiceUser()
    let service: RuuviServiceOwnershipImpl
    init() throws {
        data = try CloudSyncFixture()
        data.cloud.allowOwnership = true
        let properties = RuuviServiceSensorPropertiesImpl(
            pool: data.pool, cloud: data.cloud, coreImage: OwnershipImageCrop(), localImages: images)
        service = RuuviServiceOwnershipImpl(
            cloud: data.cloud, pool: data.pool, propertiesService: properties,
            localIDs: data.ids, localImages: images, storage: data.storage, alertService: data.alerts,
            ruuviUser: user, localSyncState: data.syncState, settings: data.settings, gattService: OwnershipIdleGatt())
    }
    func close() { data.close() }
}
final class OwnershipServiceUser: RuuviUser {
    var apiKey: String? = "test-key"
    var email: String? = "owner@example.com"
    var isAuthorized = true
    func login(apiKey: String) { self.apiKey = apiKey }
    func logout() { apiKey = nil; email = nil; isAuthorized = false }
}
private struct OwnershipImageCrop: RuuviCoreImage {
    func cropped(image: UIImage, to maxSize: CGSize) -> UIImage { image }
}
private final class OwnershipIdleGatt: GATTService {
    func isSyncingLogs() -> Bool { false }
    func isSyncingLogs(with uuid: String) -> Bool { false }
    // swiftlint:disable:next function_parameter_count
    func syncLogs(
        uuid: String, mac: String?, firmware: Int, from: Date, settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?, timeouts: GATTServiceTimeouts
    ) async throws(RuuviServiceError) -> Bool { false }
    func stopGattSync(for uuid: String) async throws(RuuviServiceError) -> Bool { true }
}
