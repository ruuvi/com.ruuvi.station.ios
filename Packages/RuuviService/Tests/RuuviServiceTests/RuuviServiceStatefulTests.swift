@testable import RuuviLocal
@testable import RuuviService
import RuuviCloud
import RuuviOntology
import RuuviPool
import RuuviRepository
import XCTest

final class RuuviServiceStatefulTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetTestUserDefaults()
    }

    func testSensorPropertiesSetNameUpdatesPoolAndCloudForCloudSensor() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )
        let sensor = makeSensor(name: "Old", isCloud: true)

        let result = try await sut.set(name: "New", for: sensor)

        XCTAssertEqual(result.name, "New")
        XCTAssertEqual(pool.updatedSensors.first?.name, "New")
        await waitUntil {
            cloud.updateNameCalls.count == 1
        }
        XCTAssertEqual(cloud.updateNameCalls.first?.1, "New")
    }

    func testSensorPropertiesSetNameForLocalSensorUpdatesOnlyPool() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )
        let sensor = makeSensor(name: "Old", isCloud: false)

        let result = try await sut.set(name: "New", for: sensor)

        XCTAssertEqual(result.name, "New")
        XCTAssertEqual(pool.updatedSensors.first?.name, "New")
        XCTAssertTrue(cloud.updateNameCalls.isEmpty)
    }

    func testSensorPropertiesSetImageForCloudSensorStoresLocallyUploadsAndClearsProgress() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let coreImage = CoreImageSpy()
        let localImages = LocalImagesSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: coreImage,
            localImages: localImages
        )
        let sensor = makeSensor(isCloud: true)
        var progressUpdates: [Double] = []

        let url = try await sut.set(
            image: makeImage(color: .black, size: CGSize(width: 64, height: 64)),
            for: sensor,
            progress: { _, progress in
                progressUpdates.append(progress)
            },
            maxSize: CGSize(width: 16, height: 16),
            compressionQuality: 0.7
        )

        XCTAssertEqual(url, localImages.setCustomBackgroundURL)
        XCTAssertEqual(coreImage.lastMaxSize, CGSize(width: 16, height: 16))
        XCTAssertEqual(localImages.setCustomBackgroundCalls.count, 1)
        XCTAssertEqual(localImages.setCustomBackgroundCalls.first?.identifier, sensor.macId?.value)
        XCTAssertEqual(cloud.uploadCalls.count, 1)
        XCTAssertEqual(progressUpdates, [0.25, 1.0])
        if let macId = sensor.macId {
            XCTAssertNil(localImages.backgroundUploadProgress(for: macId))
        }
        await waitUntil {
            !pool.updatedSensors.isEmpty
        }
    }

    func testSensorPropertiesSetImageForCloudLuidSensorStoresLocallyWithoutUpload() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localImages = LocalImagesSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: localImages
        )
        let sensor = makeSensor(macId: nil, isCloud: true)

        let url = try await sut.set(
            image: makeImage(color: .black, size: CGSize(width: 64, height: 64)),
            for: sensor,
            progress: nil,
            maxSize: CGSize(width: 16, height: 16),
            compressionQuality: 0.7
        )

        XCTAssertEqual(url, localImages.setCustomBackgroundURL)
        XCTAssertEqual(localImages.setCustomBackgroundCalls.first?.identifier, sensor.luid?.value)
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
        await waitUntil {
            !pool.updatedSensors.isEmpty
        }
    }

    func testSensorPropertiesSetImageForLocalMacSensorSkipsCloudUpload() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localImages = LocalImagesSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: localImages
        )
        let sensor = makeSensor(isCloud: false)

        let url = try await sut.set(
            image: makeImage(color: .blue, size: CGSize(width: 32, height: 32)),
            for: sensor,
            progress: nil,
            maxSize: CGSize(width: 12, height: 12),
            compressionQuality: 0.5
        )

        XCTAssertEqual(url, localImages.setCustomBackgroundURL)
        XCTAssertEqual(localImages.setCustomBackgroundCalls.first?.identifier, sensor.macId?.value)
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
        await waitUntil {
            !pool.updatedSensors.isEmpty
        }
    }

    func testSensorPropertiesSetImageForLocalLuidSensorSkipsCloudUpload() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localImages = LocalImagesSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: localImages
        )
        let sensor = makeSensor(macId: nil, isCloud: false)

        let url = try await sut.set(
            image: makeImage(color: .green, size: CGSize(width: 32, height: 32)),
            for: sensor,
            progress: nil,
            maxSize: CGSize(width: 12, height: 12),
            compressionQuality: 0.5
        )

        XCTAssertEqual(url, localImages.setCustomBackgroundURL)
        XCTAssertEqual(localImages.setCustomBackgroundCalls.first?.identifier, sensor.luid?.value)
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
        await waitUntil {
            !pool.updatedSensors.isEmpty
        }
    }

    func testSensorPropertiesSetImageFailsWithoutIdentifiers() async {
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )

        do {
            _ = try await sut.set(
                image: makeImage(color: .black),
                for: makeSensor(luid: nil, macId: nil),
                progress: nil,
                maxSize: CGSize(width: 12, height: 12),
                compressionQuality: 0.5
            )
            XCTFail("Expected missing identifier error")
        } catch let error as RuuviServiceError {
            guard case .bothLuidAndMacAreNil = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSensorPropertiesGetImageFallsBackToGeneratedLuidImage() async throws {
        let localImages = LocalImagesSpy()
        let expectedImage = makeImage(color: .yellow)
        localImages.generatedBackgrounds["luid-1"] = expectedImage
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: localImages
        )

        let image = try await sut.getImage(for: makeSensor())

        XCTAssertNotNil(image.pngData())
        XCTAssertEqual(image.pngData(), expectedImage.pngData())
    }

    func testSensorPropertiesGetImagePrefersMacBackgroundOverGeneratedFallback() async throws {
        let localImages = LocalImagesSpy()
        let expectedImage = makeImage(color: .orange)
        localImages.backgrounds["AA:BB:CC:11:22:33"] = expectedImage
        localImages.generatedBackgrounds["luid-1"] = makeImage(color: .yellow)
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: localImages
        )

        let image = try await sut.getImage(for: makeSensor())

        XCTAssertEqual(image.pngData(), expectedImage.pngData())
    }

    func testSensorPropertiesSetNextDefaultBackgroundForCloudSensorResetsCloudAndUpdatesTimestamp() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localImages = LocalImagesSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: localImages
        )
        let sensor = makeSensor(isCloud: true)

        let image = try await sut.setNextDefaultBackground(for: sensor)

        XCTAssertEqual(image.pngData(), localImages.nextDefaultBackgroundImage.pngData())
        await waitUntil {
            cloud.resetImageCalls.count == 1 && !pool.updatedSensors.isEmpty
        }
        XCTAssertEqual(cloud.resetImageCalls.first, sensor.macId?.value)
    }

    func testSensorPropertiesSetNextDefaultBackgroundFailsWithoutIdentifiers() async {
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )

        do {
            _ = try await sut.setNextDefaultBackground(luid: nil, macId: nil)
            XCTFail("Expected missing identifier error")
        } catch let error as RuuviServiceError {
            guard case .bothLuidAndMacAreNil = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSensorPropertiesRemoveImageClearsLocalStateAndResetsCloud() async {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localImages = LocalImagesSpy()
        let sensor = makeSensor(isCloud: true)
        localImages.customBackgrounds[sensor.macId?.value ?? ""] = makeImage(color: .black)
        localImages.customBackgrounds[sensor.luid?.value ?? ""] = makeImage(color: .gray)
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: localImages
        )

        sut.removeImage(for: sensor)

        XCTAssertEqual(
            Set(localImages.deletedCustomBackgroundIDs),
            Set([sensor.macId?.value, sensor.luid?.value].compactMap { $0 })
        )
        XCTAssertEqual(localImages.removedPictureCacheIDs, [sensor.id])
        await waitUntil {
            cloud.resetImageCalls.count == 1 && !pool.updatedSensors.isEmpty
        }
    }

    func testSensorPropertiesRemoveImageForCloudLuidSensorSkipsCloudResetWithoutMac() async {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localImages = LocalImagesSpy()
        let sensor = makeSensor(macId: nil, isCloud: true)
        localImages.customBackgrounds[sensor.luid?.value ?? ""] = makeImage(color: .gray)
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: localImages
        )

        sut.removeImage(for: sensor)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(localImages.deletedCustomBackgroundIDs, [sensor.luid?.value])
        XCTAssertEqual(localImages.removedPictureCacheIDs, [sensor.id])
        XCTAssertTrue(cloud.resetImageCalls.isEmpty)
        await waitUntil {
            !pool.updatedSensors.isEmpty
        }
    }

    func testSensorPropertiesUpdateDisplaySettingsTracksChangedFieldsAndPushesCloudValues() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        pool.readSensorSettingsResult = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            displayOrder: ["temperature"],
            defaultDisplayOrder: false,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 1),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 1)
        )
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )
        let sensor = makeSensor(isCloud: true)

        _ = try await sut.updateDisplaySettings(
            for: sensor,
            displayOrder: ["humidity", "temperature"],
            defaultDisplayOrder: false
        )

        XCTAssertNotNil(pool.displaySettingsCalls.first?.displayOrderLastUpdated)
        XCTAssertNil(pool.displaySettingsCalls.first?.defaultDisplayOrderLastUpdated)
        XCTAssertEqual(cloud.updateSensorSettingsCalls.count, 1)
        XCTAssertEqual(
            cloud.updateSensorSettingsCalls.first?.types,
            [
                RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue,
                RuuviCloudApiSetting.sensorDisplayOrder.rawValue,
            ]
        )
        XCTAssertEqual(
            cloud.updateSensorSettingsCalls.first?.values.last,
            "[\"humidity\",\"temperature\"]"
        )
    }

    func testSensorPropertiesUpdateDescriptionOnlyTimestampsChangedValueAndPushesCloud() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        pool.readSensorSettingsResult = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: "Old description",
            descriptionLastUpdated: Date(timeIntervalSince1970: 1)
        )
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )
        let sensor = makeSensor(isCloud: true)

        _ = try await sut.updateDescription(for: sensor, description: "New description")

        XCTAssertEqual(pool.descriptionCalls.first?.description, "New description")
        XCTAssertNotNil(pool.descriptionCalls.first?.descriptionLastUpdated)
        XCTAssertEqual(
            cloud.updateSensorSettingsCalls.first?.types,
            [RuuviCloudApiSetting.sensorDescription.rawValue]
        )
        XCTAssertEqual(cloud.updateSensorSettingsCalls.first?.values, ["New description"])
    }

    func testSensorPropertiesUpdateDescriptionSkipsTimestampWhenValueIsUnchanged() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        pool.readSensorSettingsResult = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: "Same",
            descriptionLastUpdated: Date(timeIntervalSince1970: 1)
        )
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )
        let sensor = makeSensor(isCloud: false)

        _ = try await sut.updateDescription(for: sensor, description: "Same")

        XCTAssertEqual(pool.descriptionCalls.first?.description, "Same")
        XCTAssertNil(pool.descriptionCalls.first?.descriptionLastUpdated)
        XCTAssertTrue(cloud.updateSensorSettingsCalls.isEmpty)
    }

    func testAuthLogoutCleansClaimedSensorsAndPostsSuccess() async throws {
        let cloud = CloudSpy()
        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let properties = SensorPropertiesSpy()
        let user = UserSpy()
        let alertService = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )
        let sensor = makeSensor(isCloud: true, isClaimed: true, isOwner: true, owner: "owner@example.com")
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        storage.readAllResult = [sensor.any]
        syncState.setSyncDate(Date())
        syncState.setSyncDate(Date(), for: sensor.macId)
        syncState.setGattSyncDate(Date(), for: sensor.macId)
        syncState.setAutoGattSyncAttemptDate(Date(), for: sensor.macId)
        settings.setOwnerCheckDate(for: sensor.macId, value: Date())
        settings.setCardToOpenFromWidget(for: sensor.macId?.value)
        settings.setLastOpenedChart(with: sensor.id)
        settings.setKeepConnectionDialogWasShown(true, for: sensor.luid!)
        settings.setFirmwareUpdateDialogWasShown(true, for: sensor.luid!)
        settings.setSyncDialogHidden(true, for: sensor.luid!)
        settings.setShowCustomTempAlertBound(true, for: sensor.id)
        alertService.register(type: .temperature(lower: 0, upper: 10), ruuviTag: sensor)
        let willLogout = expectation(forNotification: .RuuviAuthServiceWillLogout, object: nil)
        let didFinish = expectation(forNotification: .RuuviAuthServiceLogoutDidFinish, object: nil) { note in
            let success = note.userInfo?[RuuviAuthServiceLogoutDidFinishKey.success] as? Bool
            return success == true
        }
        let didLogout = expectation(forNotification: .RuuviAuthServiceDidLogout, object: nil)
        let sut = RuuviServiceAuthImpl(
            ruuviUser: user,
            pool: pool,
            storage: storage,
            propertiesService: properties,
            localIDs: localIDs,
            localSyncState: syncState,
            alertService: alertService,
            settings: settings
        )

        let result = try await sut.logout()

        XCTAssertTrue(result)
        await fulfillment(of: [willLogout, didFinish, didLogout], timeout: 1)
        XCTAssertEqual(user.logoutCallCount, 1)
        XCTAssertEqual(pool.deletedSensors.first?.id, sensor.id)
        XCTAssertEqual(pool.deletedAllRecordIDs, [sensor.id])
        XCTAssertEqual(pool.deletedLastIDs, [sensor.id])
        XCTAssertEqual(pool.deleteQueuedRequestsCallCount, 1)
        XCTAssertEqual(properties.removedImageSensorIDs, [sensor.id])
        XCTAssertNil(syncState.getSyncDate())
        XCTAssertNil(syncState.getSyncDate(for: sensor.macId))
        XCTAssertNil(settings.cardToOpenFromWidget())
        XCTAssertNil(settings.lastOpenedChart())
        XCTAssertFalse(alertService.hasRegistrations(for: physicalSensor))
    }

    func testAuthLogoutPostsFailureWhenDeletionFails() async {
        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let pool = PoolSpy()
        pool.deleteSensorError = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        let storage = StorageSpy()
        storage.readAllResult = [makeSensor(isCloud: true, isClaimed: true).any]
        let alertService = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )
        let finish = expectation(forNotification: .RuuviAuthServiceLogoutDidFinish, object: nil) { note in
            let success = note.userInfo?[RuuviAuthServiceLogoutDidFinishKey.success] as? Bool
            return success == false
        }
        let sut = RuuviServiceAuthImpl(
            ruuviUser: UserSpy(),
            pool: pool,
            storage: storage,
            propertiesService: SensorPropertiesSpy(),
            localIDs: localIDs,
            localSyncState: syncState,
            alertService: alertService,
            settings: settings
        )

        do {
            _ = try await sut.logout()
            XCTFail("Expected logout to fail")
        } catch let error as RuuviServiceError {
            guard case let .ruuviPool(poolError) = error,
                  case let .ruuviPersistence(persistenceError) = poolError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [finish], timeout: 1)
    }

    func testOwnershipClaimRequiresMacId() async {
        let sut = RuuviServiceOwnershipImpl(
            cloud: CloudSpy(),
            pool: PoolSpy(),
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )

        do {
            _ = try await sut.claim(sensor: makeSensor(macId: nil))
            XCTFail("Expected missing mac error")
        } catch let error as RuuviServiceError {
            guard case .macIdIsNil = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOwnershipAddPersistsSensorAndAdvertisementRecord() async throws {
        let pool = PoolSpy()
        let sensor = makeSensor()
        let record = makeRecord(source: .log)
        let sut = RuuviServiceOwnershipImpl(
            cloud: CloudSpy(),
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )

        let result = try await sut.add(sensor: sensor, record: record)

        XCTAssertEqual(result.id, sensor.id)
        XCTAssertEqual(pool.createdSensors.first?.id, sensor.id)
        XCTAssertEqual(pool.createdRecord?.source, .advertisement)
        XCTAssertEqual(pool.createdLastRecord?.source, .advertisement)
    }

    func testOwnershipRemoveDeletesLocalStateAndUnclaimsCloudOwnerSensor() async throws {
        let cloud = CloudSpy()
        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let pool = PoolSpy()
        let storage = StorageSpy()
        storage.readAllResult = []
        let properties = SensorPropertiesSpy()
        let alertService = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )
        let sensor = makeSensor(isCloud: true, isClaimed: true, isOwner: true, owner: "owner@example.com")
        syncState.setSyncDate(Date())
        syncState.setSyncDate(Date(), for: sensor.macId)
        settings.setCardToOpenFromWidget(for: sensor.macId?.value)
        settings.setLastOpenedChart(with: sensor.id)
        settings.setShowCustomTempAlertBound(true, for: sensor.id)
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: properties,
            localIDs: localIDs,
            localImages: LocalImagesSpy(),
            storage: storage,
            alertService: alertService,
            ruuviUser: UserSpy(),
            localSyncState: syncState,
            settings: settings
        )

        let result = try await sut.remove(sensor: sensor, removeCloudHistory: true)

        XCTAssertEqual(result.id, sensor.id)
        XCTAssertEqual(properties.removedImageSensorIDs, [sensor.id])
        XCTAssertEqual(pool.deletedSensors.first?.id, sensor.id)
        XCTAssertEqual(pool.deletedAllRecordIDs, [sensor.id])
        XCTAssertEqual(pool.deletedLastIDs, [sensor.id])
        XCTAssertEqual(pool.deletedSensorSettings.first?.id, sensor.id)
        XCTAssertEqual(cloud.unclaimCalls.first?.0, sensor.macId?.value)
        XCTAssertNil(settings.cardToOpenFromWidget())
        XCTAssertNil(settings.lastOpenedChart())
        await waitUntil {
            syncState.getSyncDate() == nil
        }
    }

    func testOwnershipCheckOwnerStoresFullMacMapping() async throws {
        let cloud = CloudSpy()
        cloud.checkOwnerResult = ("owner@example.com", "AA:BB:CC:DD:EE:FF")
        let localIDs = RuuviLocalIDsUserDefaults()
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: PoolSpy(),
            propertiesService: SensorPropertiesSpy(),
            localIDs: localIDs,
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )
        let shortMac = "DD:EE:FF".mac

        let result = try await sut.checkOwner(macId: shortMac)

        XCTAssertEqual(result.1, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(localIDs.fullMac(for: shortMac)?.value, "aa:bb:cc:dd:ee:ff")
    }

    func testOwnershipWrapperMethodsDelegateToCloud() async throws {
        let cloud = CloudSpy()
        let sensor = makeSensor(isCloud: true)
        cloud.loadSharedResult = [
            ShareableSensorStruct(
                id: sensor.id,
                canShare: true,
                sharedTo: ["guest@example.com"]
            ).any
        ]
        cloud.shareResult = ShareSensorResponse(macId: "AA:BB:CC:11:22:33".mac, invited: false)
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: PoolSpy(),
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )

        let shared = try await sut.loadShared(for: sensor)
        let share = try await sut.share(macId: sensor.macId!, with: "guest@example.com")
        let unshared = try await sut.unshare(macId: sensor.macId!, with: "guest@example.com")

        XCTAssertEqual(shared.count, 1)
        XCTAssertEqual(cloud.shareCalls.first?.0, sensor.macId?.value)
        XCTAssertEqual(cloud.shareCalls.first?.1, "guest@example.com")
        XCTAssertEqual(share.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(cloud.unshareCalls.first?.0, sensor.macId?.value)
        XCTAssertEqual(cloud.unshareCalls.first?.1, "guest@example.com")
        XCTAssertEqual(unshared.value, "AA:BB:CC:11:22:33")
    }

    func testOwnershipClaimUsesFullMacLookupForV6Sensor() async throws {
        let cloud = CloudSpy()
        cloud.checkOwnerResult = ("owner@example.com", "AA:BB:CC:DD:EE:FF")
        let pool = PoolSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let user = UserSpy()
        user.email = "owner@example.com"
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: localIDs,
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: user,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )
        let sensor = makeSensor(macId: "DD:EE:FF", version: 6)

        let result = try await sut.claim(sensor: sensor)

        XCTAssertEqual(cloud.claimCalls.first?.1, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(localIDs.fullMac(for: "DD:EE:FF".mac)?.value, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(result.owner, "owner@example.com")
        XCTAssertEqual(pool.updatedSensors.first?.isOwner, true)
        XCTAssertEqual(pool.updatedSensors.first?.isCloud, true)
    }

    func testOwnershipClaimWithV6ShortMacUsesOriginalMacWhenFullMacIsUnavailable() async throws {
        let cloud = CloudSpy()
        cloud.checkOwnerResult = ("owner@example.com", nil)
        let pool = PoolSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let user = UserSpy()
        user.email = "owner@example.com"
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: localIDs,
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: user,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )
        let sensor = makeSensor(macId: "DD:EE:FF", version: 6)

        let result = try await sut.claim(sensor: sensor)

        XCTAssertEqual(cloud.claimCalls.first?.1, "DD:EE:FF")
        XCTAssertNil(localIDs.fullMac(for: "DD:EE:FF".mac))
        XCTAssertEqual(result.owner, "owner@example.com")
    }

    func testOwnershipContestMarksSensorClaimedForAuthorizedUser() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let user = UserSpy()
        user.email = "owner@example.com"
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: localIDs,
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: user,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )
        let sensor = makeSensor()

        let result = try await sut.contest(sensor: sensor, secret: "secret-123")

        XCTAssertEqual(cloud.contestCalls.first?.0, sensor.macId?.value)
        XCTAssertEqual(cloud.contestCalls.first?.1, "secret-123")
        XCTAssertEqual(result.owner, "owner@example.com")
        XCTAssertEqual(pool.updatedSensors.first?.isClaimed, true)
    }

    func testOwnershipContestUploadsCustomBackgroundOffsetsAndExistingAlerts() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let localImages = LocalImagesSpy()
        let storage = StorageSpy()
        let user = UserSpy()
        user.email = "owner@example.com"
        let alertService = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: makeSettings()
        )
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: localIDs,
            localImages: localImages,
            storage: storage,
            alertService: alertService,
            ruuviUser: user,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )
        let sensor = makeSensor()
        storage.readSensorSettingsResult = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1.25,
            humidityOffset: 0.22,
            pressureOffset: 3.0
        )
        localImages.customBackgrounds[sensor.macId?.value ?? ""] = makeImage(color: .magenta)
        alertService.register(type: .temperature(lower: -1, upper: 5), ruuviTag: sensor)

        let result = try await sut.contest(sensor: sensor, secret: "secret-123")

        XCTAssertEqual(result.owner, "owner@example.com")
        XCTAssertEqual(cloud.contestCalls.first?.0, sensor.macId?.value)
        XCTAssertEqual(cloud.uploadCalls.first?.macId, sensor.macId?.value)
        XCTAssertFalse(cloud.uploadCalls.first?.data.isEmpty ?? true)
        await waitUntil {
            cloud.updateOffsetCalls.count == 1
        }
        XCTAssertEqual(cloud.updateOffsetCalls.first?.temperatureOffset, 1.25)
        XCTAssertEqual(cloud.updateOffsetCalls.first?.humidityOffset ?? 0, 22, accuracy: 0.0001)
        XCTAssertEqual(cloud.updateOffsetCalls.first?.pressureOffset ?? 0, 300, accuracy: 0.0001)
        XCTAssertEqual(
            alertService.alert(for: result, of: .temperature(lower: -1, upper: 5)),
            .temperature(lower: -1, upper: 5)
        )
    }

    func testOwnershipContestRequiresMacId() async {
        let cloud = CloudSpy()
        let user = UserSpy()
        user.email = "owner@example.com"
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: PoolSpy(),
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: user,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )

        do {
            _ = try await sut.contest(sensor: makeSensor(macId: nil), secret: "secret")
            XCTFail("Expected contest to reject sensors without a MAC.")
        } catch RuuviServiceError.macIdIsNil {
            XCTAssertTrue(cloud.contestCalls.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOwnershipUnclaimClearsCloudStateAndUpdatesPool() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sensor = makeSensor(isCloud: true, isClaimed: true, isOwner: true, owner: "owner@example.com")
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )

        let result = try await sut.unclaim(sensor: sensor, removeCloudHistory: true)

        XCTAssertEqual(cloud.unclaimCalls.first?.0, sensor.macId?.value)
        XCTAssertEqual(cloud.unclaimCalls.first?.1, true)
        XCTAssertFalse(result.isClaimed)
        XCTAssertFalse(result.isCloud)
        XCTAssertNil(result.owner)
        XCTAssertEqual(pool.updatedSensors.first?.isCloud, false)
    }

    func testOwnershipRemoveCloudGuestSensorUnsharesInsteadOfUnclaiming() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sensor = makeSensor(isCloud: true, isClaimed: true, isOwner: false, owner: "owner@example.com")
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )

        _ = try await sut.remove(sensor: sensor, removeCloudHistory: false)

        await waitUntil {
            !cloud.unshareCalls.isEmpty
        }
        XCTAssertTrue(cloud.unclaimCalls.isEmpty)
        XCTAssertEqual(cloud.unshareCalls.first?.0, sensor.macId?.value)
        XCTAssertNil(cloud.unshareCalls.first?.1)
        XCTAssertEqual(pool.deletedSensors.first?.id, sensor.id)
    }

    func testOwnershipRemoveLocalSensorDeletesOnlyLocalStateAndClearsGlobalSyncDate() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let properties = SensorPropertiesSpy()
        let storage = StorageSpy()
        storage.readAllResult = []
        let syncState = RuuviLocalSyncStateUserDefaults()
        syncState.setSyncDate(Date(timeIntervalSince1970: 1_700_000_000))
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: properties,
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: storage,
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: syncState,
            settings: makeSettings()
        )
        let sensor = makeSensor(isCloud: false, isClaimed: false, isOwner: false)

        let result = try await sut.remove(sensor: sensor, removeCloudHistory: false)

        XCTAssertEqual(result.id, sensor.id)
        XCTAssertEqual(pool.deletedSensors.first?.id, sensor.id)
        XCTAssertEqual(pool.deletedAllRecordIDs, [sensor.id])
        XCTAssertEqual(pool.deletedLastIDs, [sensor.id])
        XCTAssertEqual(pool.deletedSensorSettings.first?.id, sensor.id)
        XCTAssertEqual(properties.removedImageSensorIDs, [sensor.id])
        XCTAssertTrue(cloud.unclaimCalls.isEmpty)
        XCTAssertTrue(cloud.unshareCalls.isEmpty)
        await waitUntil {
            syncState.getSyncDate() == nil
        }
    }

    func testOwnershipUpdateShareableDelegatesToPool() async throws {
        let pool = PoolSpy()
        let sensor = makeSensor(isCloud: true)
        let sut = RuuviServiceOwnershipImpl(
            cloud: CloudSpy(),
            pool: pool,
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: makeSettings()
        )

        let result = try await sut.updateShareable(for: sensor)

        XCTAssertTrue(result)
        XCTAssertEqual(pool.updatedSensors.first?.id, sensor.id)
    }

    func testCloudSyncImageCachesDownloadedPicture() async throws {
        let cloud = CloudSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let localImages = LocalImagesSpy()
        let pictureURL = URL(string: "https://example.com/cloud-image.jpg")!
        var requestedURL: URL?
        let imageData = try XCTUnwrap(makeImage(color: .cyan).pngData())
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: StorageSpy(),
            ruuviCloud: cloud,
            ruuviPool: PoolSpy(),
            ruuviLocalSettings: makeSettings(),
            ruuviLocalSyncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalImages: localImages,
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: localIDs,
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: makeSettings()
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(
                cloud: cloud,
                localSettings: makeSettings()
            ),
            imageDataLoader: { url in
                requestedURL = url
                return imageData
            }
        )
        let sensor = makeCloudSensor(id: "AA:BB:CC:11:22:33", picture: pictureURL)

        let fileURL = try await sut.syncImage(sensor: sensor)

        XCTAssertEqual(requestedURL, pictureURL)
        XCTAssertEqual(fileURL, localImages.setCustomBackgroundURL)
        XCTAssertEqual(localImages.setCustomBackgroundCalls.first?.identifier, sensor.id)
        XCTAssertEqual(localImages.setCustomBackgroundCalls.first?.compressionQuality, 1.0)
        XCTAssertEqual(localImages.setPictureIsCachedIDs, [sensor.id])
    }

    func testCloudSyncImageRejectsInvalidImageData() async throws {
        let cloud = CloudSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: StorageSpy(),
            ruuviCloud: cloud,
            ruuviPool: PoolSpy(),
            ruuviLocalSettings: makeSettings(),
            ruuviLocalSyncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: localIDs,
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: makeSettings()
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(
                cloud: cloud,
                localSettings: makeSettings()
            ),
            imageDataLoader: { _ in Data("not-image".utf8) }
        )
        let sensor = makeCloudSensor(
            id: "AA:BB:CC:11:22:44",
            picture: URL(string: "https://example.com/bad-image.jpg")
        )

        do {
            _ = try await sut.syncImage(sensor: sensor)
            XCTFail("Expected invalid image data to be rejected.")
        } catch RuuviServiceError.failedToParseNetworkResponse {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCloudSyncImageRequiresPictureURL() async throws {
        let cloud = CloudSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: StorageSpy(),
            ruuviCloud: cloud,
            ruuviPool: PoolSpy(),
            ruuviLocalSettings: makeSettings(),
            ruuviLocalSyncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: localIDs,
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: makeSettings()
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(
                cloud: cloud,
                localSettings: makeSettings()
            ),
            imageDataLoader: { _ in
                XCTFail("Image data loader should not run without a picture URL.")
                return Data()
            }
        )

        do {
            _ = try await sut.syncImage(sensor: makeCloudSensor(picture: nil))
            XCTFail("Expected missing picture URL to be rejected.")
        } catch RuuviServiceError.pictureUrlIsNil {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCloudSyncRecordsOperationMapsLuidAndPersistsRecords() async {
        let cloud = CloudSpy()
        let repository = RepositorySpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let macId = "AA:BB:CC:11:22:33".mac
        localIDs.set(luid: "persisted-luid".luid, for: macId)
        cloud.loadRecordsResult = [makeRecord(luid: nil).any]
        let operation = RuuviServiceCloudSyncRecordsOperation(
            sensor: makeSensor(),
            since: Date(timeIntervalSince1970: 0),
            ruuviCloud: cloud,
            ruuviRepository: repository,
            syncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalIDs: localIDs
        )

        operation.start()
        await waitUntil {
            operation.isFinished
        }

        XCTAssertEqual(repository.createdRecords.count, 1)
        XCTAssertEqual(repository.createdRecords.first?.luid?.value, "persisted-luid")
        XCTAssertEqual(operation.records.first?.luid?.value, "persisted-luid")
    }

    func testCloudSyncRecordsOperationMapsRepositoryErrors() async {
        let repository = RepositorySpy()
        repository.createRecordsError = RuuviRepositoryError.ruuviStorage(.ruuviPersistence(.failedToFindRuuviTag))
        let cloud = CloudSpy()
        cloud.loadRecordsResult = [makeRecord().any]
        let operation = RuuviServiceCloudSyncRecordsOperation(
            sensor: makeSensor(),
            since: Date(),
            ruuviCloud: cloud,
            ruuviRepository: repository,
            syncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults()
        )

        operation.start()
        await waitUntil {
            operation.isFinished
        }

        guard case let .ruuviRepository(error)? = operation.error,
              case let .ruuviStorage(storageError) = error,
              case let .ruuviPersistence(persistenceError) = storageError,
              case .failedToFindRuuviTag = persistenceError else {
            return XCTFail("Unexpected operation error: \(String(describing: operation.error))")
        }
    }

    func testCloudSyncRecordsOperationFailsWithoutMacId() {
        let operation = RuuviServiceCloudSyncRecordsOperation(
            sensor: makeSensor(macId: nil),
            since: Date(),
            ruuviCloud: CloudSpy(),
            ruuviRepository: RepositorySpy(),
            syncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults()
        )

        operation.start()

        XCTAssertTrue(operation.isFinished)
        guard case .macIdIsNil? = operation.error else {
            return XCTFail("Expected macIdIsNil")
        }
    }

    func testCloudSyncSyncSettingsUpdatesLocalStateAndBackfillsMissingLanguage() async throws {
        let cloud = CloudSpy()
        cloud.getCloudSettingsResult = makeCloudSettings(profileLanguageCode: nil)
        let settings = makeSettings()
        settings.language = .finnish
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: StorageSpy(),
            ruuviCloud: cloud,
            ruuviPool: PoolSpy(),
            ruuviLocalSettings: settings,
            ruuviLocalSyncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults(),
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)
        )

        _ = try await sut.syncSettings()

        XCTAssertEqual(settings.temperatureUnit, .fahrenheit)
        XCTAssertEqual(settings.humidityUnit, .dew)
        XCTAssertEqual(settings.pressureUnit, .millimetersOfMercury)
        XCTAssertTrue(settings.chartStatsOn)
        XCTAssertFalse(settings.chartDrawDotsOn)
        XCTAssertEqual(settings.cloudProfileLanguageCode, "fi")
        await waitUntil {
            cloud.setProfileLanguageCodeValues == ["fi"]
        }
    }

    func testCloudSyncQueuedRequestDeletesRequestOnConflict() async {
        let cloud = CloudSpy()
        cloud.executeQueuedRequestError = RuuviCloudError.api(.api(.erConflict))
        let pool = PoolSpy()
        let request = makeQueuedRequest()
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: StorageSpy(),
            ruuviCloud: cloud,
            ruuviPool: pool,
            ruuviLocalSettings: makeSettings(),
            ruuviLocalSyncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults(),
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: makeSettings())
        )

        do {
            _ = try await sut.syncQueuedRequest(request: request)
            XCTFail("Expected conflict error")
        } catch let error as RuuviServiceError {
            guard case let .ruuviCloud(cloudError) = error,
                  case let .api(apiError) = cloudError,
                  case let .api(code) = apiError,
                  code == .erConflict else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(pool.deletedQueuedRequests.count, 1)
    }

    func testCloudSyncSyncSettingsUnauthorizedPostsAuthorizationNotification() async {
        let cloud = CloudSpy()
        cloud.getCloudSettingsError = RuuviCloudError.api(.api(.erUnauthorized))
        let expectation = expectation(
            forNotification: .NetworkSyncDidFailForAuthorization,
            object: nil
        )
        let sut = makeCloudSyncService(cloud: cloud, settings: makeSettings())

        do {
            _ = try await sut.syncSettings()
            XCTFail("Expected unauthorized error")
        } catch let error as RuuviServiceError {
            guard case let .ruuviCloud(cloudError) = error,
                  case let .api(apiError) = cloudError,
                  case let .api(code) = apiError,
                  code == .erUnauthorized else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testCloudSyncExecutePendingRequestsReplaysAllQueuedRequestsAndDeletesThem() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        storage.readQueuedRequestsResult = [
            makeQueuedRequest(uniqueKey: "queued-1"),
            makeQueuedRequest(uniqueKey: "queued-2"),
        ]
        let sut = makeCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.executePendingRequests()

        XCTAssertTrue(result)
        XCTAssertEqual(cloud.executedRequests, ["queued-1", "queued-2"])
        XCTAssertEqual(pool.deletedQueuedRequests.count, 2)
    }

    func testCloudSyncQueuedRequestDeletesRequestOnSuccess() async throws {
        let pool = PoolSpy()
        let request = makeQueuedRequest(uniqueKey: "success")
        let sut = makeCloudSyncService(
            cloud: CloudSpy(),
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.syncQueuedRequest(request: request)

        XCTAssertTrue(result)
        XCTAssertEqual(pool.deletedQueuedRequests.count, 1)
    }

    func testCloudSyncRefreshLatestRecordQueuesLocalSensorChangesWhenLocalDataIsNewer() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let localImages = LocalImagesSpy()
        let settings = makeSettings()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:33",
            name: "Local Sensor",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 300)
        )
        localImages.customBackgrounds[sensor.macId?.value ?? ""] = makeImage(color: .red)
        storage.readAllResult = [sensor.any]
        storage.readSensorSettingsResult = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1.25,
            humidityOffset: 0.22,
            pressureOffset: 3.0,
            description: "Local description",
            displayOrder: ["temperature", "humidity"],
            defaultDisplayOrder: true,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 300),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 300),
            descriptionLastUpdated: Date(timeIntervalSince1970: 300)
        )
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: "Cloud Sensor",
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: "pro",
                    picture: URL(string: "https://example.com/cloud.jpg"),
                    offsetTemperature: 0.5,
                    offsetHumidity: 15,
                    offsetPressure: 120,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: Date(timeIntervalSince1970: 200)
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil,
                settings: RuuviCloudSensorSettings(
                    displayOrderCodes: ["humidity"],
                    defaultDisplayOrder: false,
                    displayOrderLastUpdated: Date(timeIntervalSince1970: 200),
                    defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 200),
                    description: "Cloud description",
                    descriptionLastUpdated: Date(timeIntervalSince1970: 200)
                )
            )
        ]
        let sut = makeCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: settings,
            syncState: syncState,
            localImages: localImages
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        await waitUntil {
            cloud.updateNameCalls.count == 1
                && cloud.uploadCalls.count == 1
                && cloud.updateOffsetCalls.count == 1
                && cloud.updateSensorSettingsCalls.count == 1
        }
        XCTAssertEqual(cloud.updateNameCalls.first?.0, sensor.id)
        XCTAssertEqual(cloud.uploadCalls.first?.macId, sensor.macId?.value)
        XCTAssertEqual(cloud.updateOffsetCalls.first?.temperatureOffset, 1.25)
        XCTAssertEqual(cloud.updateOffsetCalls.first?.humidityOffset ?? 0, 22, accuracy: 0.0001)
        XCTAssertEqual(cloud.updateOffsetCalls.first?.pressureOffset ?? 0, 300, accuracy: 0.0001)
        XCTAssertEqual(
            cloud.updateSensorSettingsCalls.first?.types,
            [
                RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue,
                RuuviCloudApiSetting.sensorDisplayOrder.rawValue,
                RuuviCloudApiSetting.sensorDescription.rawValue
            ]
        )
        XCTAssertEqual(
            cloud.updateSensorSettingsCalls.first?.values,
            ["true", "[\"temperature\",\"humidity\"]", "Local description"]
        )
        XCTAssertEqual(syncState.getSyncStatusLatestRecord(for: sensor.macId!), .complete)
        XCTAssertTrue(pool.offsetCorrectionCalls.isEmpty)
        XCTAssertTrue(pool.displaySettingsCalls.isEmpty)
        XCTAssertTrue(pool.descriptionCalls.isEmpty)
    }

    func testCloudSyncRefreshLatestRecordUpdatesLocalOffsetsAndDisplaySettingsWhenCloudIsNewer() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:33",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        storage.readAllResult = [sensor.any]
        storage.readSensorSettingsResult = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 0.1,
            humidityOffset: 0.2,
            pressureOffset: 0.3,
            description: "Local description",
            displayOrder: ["temperature"],
            defaultDisplayOrder: true,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 100),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 100),
            descriptionLastUpdated: Date(timeIntervalSince1970: 100)
        )
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: "Cloud Sensor",
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: "pro",
                    picture: nil,
                    offsetTemperature: 1.5,
                    offsetHumidity: 45,
                    offsetPressure: 250,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: Date(timeIntervalSince1970: 200)
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil,
                settings: RuuviCloudSensorSettings(
                    displayOrderCodes: ["humidity"],
                    defaultDisplayOrder: false,
                    displayOrderLastUpdated: Date(timeIntervalSince1970: 200),
                    defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 200),
                    description: "Cloud description",
                    descriptionLastUpdated: Date(timeIntervalSince1970: 200)
                )
            )
        ]
        let sut = makeCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.updatedSensors.first?.name, "Cloud Sensor")
        XCTAssertEqual(pool.offsetCorrectionCalls.count, 3)
        XCTAssertEqual(pool.offsetCorrectionCalls.map(\.type), [.temperature, .humidity, .pressure])
        XCTAssertEqual(pool.offsetCorrectionCalls[0].value ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(pool.offsetCorrectionCalls[1].value ?? 0, 0.45, accuracy: 0.0001)
        XCTAssertEqual(pool.offsetCorrectionCalls[2].value ?? 0, 2.5, accuracy: 0.0001)
        XCTAssertEqual(pool.displaySettingsCalls.first?.displayOrder, ["humidity"])
        XCTAssertEqual(pool.displaySettingsCalls.first?.defaultDisplayOrder, false)
        XCTAssertEqual(pool.descriptionCalls.first?.description, "Cloud description")
        XCTAssertTrue(cloud.updateOffsetCalls.isEmpty)
        XCTAssertTrue(cloud.updateSensorSettingsCalls.isEmpty)
    }

    func testCloudSyncRefreshLatestRecordCreatesNewCloudSensorsAndDeletesMissingLocalCloudSensors() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let missingLocal = makeSensor(
            luid: "luid-missing",
            macId: "AA:BB:CC:11:22:33",
            name: "Missing",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        let newCloudSensor = CloudSensorStruct(
            id: "AA:BB:CC:11:22:44",
            serviceUUID: nil,
            name: "New Cloud",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: [],
            maxHistoryDays: nil,
            lastUpdated: Date(timeIntervalSince1970: 200)
        )
        storage.readAllResult = [missingLocal.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: newCloudSensor,
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: newCloudSensor.id, alerts: []),
                subscription: nil
            )
        ]
        let sut = makeCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings(),
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.deletedSensors.map(\.id), [missingLocal.id])
        XCTAssertEqual(pool.createdSensors.map(\.id), [newCloudSensor.id])
        XCTAssertNil(syncState.downloadFullHistory(for: missingLocal.macId))
        XCTAssertEqual(syncState.getSyncStatusLatestRecord(for: missingLocal.macId!), .complete)
    }

    func testCloudSyncRefreshLatestRecordMarksPerSensorStatusOnError() async {
        let cloud = CloudSpy()
        cloud.loadSensorsDenseError = RuuviCloudError.api(.connection)
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:33",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com"
        )
        storage.readAllResult = [sensor.any]
        let sut = makeCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings(),
            syncState: syncState
        )

        do {
            _ = try await sut.refreshLatestRecord()
            XCTFail("Expected sync failure")
        } catch {
            // Intentionally empty; status assertions below validate the failure path.
        }

        XCTAssertEqual(syncState.getSyncStatusLatestRecord(for: sensor.macId!), .onError)
    }

    func testAlertRegisterPersistsCloudTemperatureAlertAndSendsCloudPayload() async {
        let cloud = CloudSpy()
        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sensor = makeSensor(isCloud: true)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )

        sut.register(type: .temperature(lower: -1, upper: 5), ruuviTag: sensor)

        XCTAssertTrue(sut.isOn(type: .temperature(lower: -1, upper: 5), for: physicalSensor))
        await waitUntil {
            cloud.setAlertCalls.count == 1
        }
        XCTAssertEqual(cloud.setAlertCalls.first?.type, .temperature)
        XCTAssertEqual(cloud.setAlertCalls.first?.min ?? 0, -1, accuracy: 0.0001)
        XCTAssertEqual(cloud.setAlertCalls.first?.max ?? 0, 5, accuracy: 0.0001)
    }

    func testAlertSyncCloudTemperatureStoresDescriptionAndCustomBoundsFlag() {
        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sensor = makeSensor()
        localIDs.set(luid: sensor.luid!, for: sensor.macId!)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )

        sut.sync(cloudAlerts: [
            CloudSensorAlertsStub(
                sensor: sensor.macId?.value,
                alerts: [
                    CloudAlertStub(
                        type: .temperature,
                        enabled: true,
                        min: -100,
                        max: 100,
                        counter: nil,
                        delay: nil,
                        description: "External probe",
                        triggered: nil,
                        triggeredAt: nil,
                        lastUpdated: nil
                    )
                ]
            )
        ])

        XCTAssertEqual(sut.temperatureDescription(for: physicalSensor), "External probe")
        XCTAssertTrue(settings.showCustomTempAlertBound(for: physicalSensor.id))
        XCTAssertTrue(sut.isOn(type: .temperature(lower: -100, upper: 100), for: physicalSensor))
    }
}

private func makeCloudSyncService(
    storage: StorageSpy = StorageSpy(),
    cloud: CloudSpy = CloudSpy(),
    pool: PoolSpy = PoolSpy(),
    settings: RuuviLocalSettingsUserDefaults,
    syncState: RuuviLocalSyncState = RuuviLocalSyncStateUserDefaults(),
    localImages: RuuviLocalImages = LocalImagesSpy(),
    repository: RepositorySpy = RepositorySpy(),
    localIDs: RuuviLocalIDs = RuuviLocalIDsUserDefaults()
) -> RuuviServiceCloudSyncImpl {
    RuuviServiceCloudSyncImpl(
        ruuviStorage: storage,
        ruuviCloud: cloud,
        ruuviPool: pool,
        ruuviLocalSettings: settings,
        ruuviLocalSyncState: syncState,
        ruuviLocalImages: localImages,
        ruuviRepository: repository,
        ruuviLocalIDs: localIDs,
        ruuviAlertService: RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: settings
        ),
        ruuviAppSettingsService: RuuviServiceAppSettingsImpl(
            cloud: cloud,
            localSettings: settings
        )
    )
}
