@testable import RuuviLocal
@preconcurrency import RuuviOntology
import UIKit
import XCTest

final class RuuviLocalStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetLocalUserDefaults()
    }

    func testUserDefaultRemovesOptionalKeyWhenSetToNil() {
        var sut = OptionalValueBox()

        sut.value = "persisted"
        XCTAssertEqual(UserDefaults.standard.string(forKey: OptionalValueBox.key), "persisted")

        sut.value = nil

        XCTAssertNil(UserDefaults.standard.object(forKey: OptionalValueBox.key))
    }

    func testLocalIDsRoundTripAllMappingsAndFullMacReverseLookup() {
        let sut = RuuviLocalIDsUserDefaults()
        let luid = UUID().uuidString.luid
        let extendedLuid = "\(UUID().uuidString)-ext".luid
        let mac = "AA:BB:CC:11:22:33".mac
        let fullMac = "aa:bb:cc:11:22:33".mac

        sut.set(mac: mac, for: luid)
        sut.set(luid: luid, for: mac)
        sut.set(extendedLuid: extendedLuid, for: mac)
        sut.set(fullMac: fullMac, for: mac)

        XCTAssertEqual(sut.mac(for: luid)?.value, mac.value)
        XCTAssertEqual(sut.luid(for: mac)?.value, luid.value)
        XCTAssertEqual(sut.extendedLuid(for: mac)?.value, extendedLuid.value)
        XCTAssertEqual(sut.fullMac(for: mac)?.value, fullMac.value)
        XCTAssertEqual(sut.originalMac(for: fullMac)?.value, mac.value)
    }

    func testLocalIDsRemoveFullMacClearsForwardAndReverseLookups() {
        let sut = RuuviLocalIDsUserDefaults()
        let mac = "AA:BB:CC:11:22:33".mac
        let fullMac = "aa:bb:cc:11:22:33".mac
        sut.set(fullMac: fullMac, for: mac)

        sut.removeFullMac(for: mac)

        XCTAssertNil(sut.fullMac(for: mac))
        XCTAssertNil(sut.originalMac(for: fullMac))
    }

    func testConnectionsPostsStartOnceAndAvoidsDuplicateEntries() {
        let sut = RuuviLocalConnectionsUserDefaults()
        let luid = UUID().uuidString.luid
        let started = expectation(
            forNotification: .ConnectionPersistenceDidStartToKeepConnection,
            object: nil
        ) { note in
            (note.userInfo?[CPDidStartToKeepConnectionKey.uuid] as? String) == luid.value
        }

        sut.setKeepConnection(true, for: luid)
        sut.setKeepConnection(true, for: luid)

        wait(for: [started], timeout: 1)
        XCTAssertTrue(sut.keepConnection(to: luid))
        XCTAssertEqual(sut.keepConnectionUUIDs.map(\.value), [luid.value])
    }

    func testConnectionsReportFalseWhenNoStoredArrayExists() {
        let sut = RuuviLocalConnectionsUserDefaults()

        XCTAssertFalse(sut.keepConnection(to: UUID().uuidString.luid))
        XCTAssertTrue(sut.keepConnectionUUIDs.isEmpty)
    }

    func testConnectionsUnpairAllClearsTrackedSensorsAndPostsStopForEach() {
        let sut = RuuviLocalConnectionsUserDefaults()
        let luid1 = UUID().uuidString.luid
        let luid2 = UUID().uuidString.luid
        sut.setKeepConnection(true, for: luid1)
        sut.setKeepConnection(true, for: luid2)

        let stopOne = expectation(
            forNotification: .ConnectionPersistenceDidStopToKeepConnection,
            object: nil
        ) { note in
            (note.userInfo?[CPDidStopToKeepConnectionKey.uuid] as? String) == luid1.value
        }
        let stopTwo = expectation(
            forNotification: .ConnectionPersistenceDidStopToKeepConnection,
            object: nil
        ) { note in
            (note.userInfo?[CPDidStopToKeepConnectionKey.uuid] as? String) == luid2.value
        }

        sut.unpairAllConnection()

        wait(for: [stopOne, stopTwo], timeout: 1)
        XCTAssertTrue(sut.keepConnectionUUIDs.isEmpty)
    }

    func testConnectionsStopRemovesTrackedUuidAndLeavesUnknownUuidDisabled() {
        let sut = RuuviLocalConnectionsUserDefaults()
        let tracked = UUID().uuidString.luid
        let unknown = UUID().uuidString.luid
        sut.setKeepConnection(true, for: tracked)

        let stopped = expectation(
            forNotification: .ConnectionPersistenceDidStopToKeepConnection,
            object: nil
        ) { note in
            (note.userInfo?[CPDidStopToKeepConnectionKey.uuid] as? String) == tracked.value
        }

        sut.setKeepConnection(false, for: tracked)

        wait(for: [stopped], timeout: 1)
        XCTAssertFalse(sut.keepConnection(to: tracked))
        XCTAssertFalse(sut.keepConnection(to: unknown))
        XCTAssertTrue(sut.keepConnectionUUIDs.isEmpty)
    }

    func testSyncStateStoresDatesFlagsAndPostsStatusNotifications() async {
        let sut = RuuviLocalSyncStateUserDefaults()
        let mac = "AA:BB:CC:11:22:33".mac
        let macValue = mac.value
        let date = Date(timeIntervalSince1970: 1234)
        let latestStatus = expectation(
            forNotification: .NetworkSyncLatestDataDidChangeStatus,
            object: nil
        ) { note in
            let status = note.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus
            let observedMac = note.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier
            return status == .complete && observedMac?.value == macValue
        }
        let historyStatus = expectation(
            forNotification: .NetworkSyncHistoryDidChangeStatus,
            object: nil
        ) { note in
            let status = note.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus
            let observedMac = note.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier
            return status == .onError && observedMac?.value == macValue
        }
        let commonStatus = expectation(
            forNotification: .NetworkSyncDidChangeCommonStatus,
            object: sut
        ) { note in
            (note.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus) == .syncing
        }

        sut.setSyncStatus(.syncing)
        sut.setSyncStatusLatestRecord(.complete, for: mac)
        sut.setSyncStatusHistory(.onError, for: mac)
        sut.setSyncDate(date, for: mac)
        sut.setGattSyncDate(date, for: mac)
        sut.setAutoGattSyncAttemptDate(date, for: mac)
        sut.setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(true, for: mac)
        sut.setDownloadFullHistory(for: mac, downloadFull: true)

        await fulfillment(of: [latestStatus, historyStatus, commonStatus], timeout: 1)
        XCTAssertEqual(sut.getSyncStatusLatestRecord(for: mac), .complete)
        XCTAssertEqual(sut.getSyncDate(for: mac), date)
        XCTAssertEqual(sut.getGattSyncDate(for: mac), date)
        XCTAssertEqual(sut.getAutoGattSyncAttemptDate(for: mac), date)
        XCTAssertTrue(sut.hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for: mac))
        XCTAssertEqual(sut.downloadFullHistory(for: mac), true)

        sut.setDownloadFullHistory(for: mac, downloadFull: nil)
        XCTAssertNil(sut.downloadFullHistory(for: mac))

        sut.syncStatus = .complete
        XCTAssertEqual(sut.syncStatus, .complete)
        sut.setSyncDate(date)
        XCTAssertEqual(sut.getSyncDate(), date)

        UserDefaults.standard.set(
            99,
            forKey: "RuuviLocalSyncStateUserDefaults.syncState.\(mac.mac)"
        )
        UserDefaults.standard.set(99, forKey: "RuuviLocalSyncStateUserDefaults.syncStatus")
        XCTAssertEqual(sut.getSyncStatusLatestRecord(for: mac), .none)
        XCTAssertEqual(sut.syncStatus, .none)
    }

    func testSyncStatusFallsBackToNoneForUnknownPersistedRawValue() {
        UserDefaults.standard.set(99, forKey: "RuuviLocalSyncStateUserDefaults.syncStatus")

        XCTAssertEqual(RuuviLocalSyncStateUserDefaults().syncStatus, .none)
    }

    func testSettingsPersistWidgetStateAndLanguageNotification() {
        let sut = RuuviLocalSettingsUserDefaults()
        let languageChanged = expectation(forNotification: .LanguageDidChange, object: sut)
        let luid = UUID().uuidString.luid
        let mac = "AA:BB:CC:11:22:33".mac
        let ownerCheckDate = Date(timeIntervalSince1970: 5678)

        sut.language = .finnish
        sut.setCardToOpenFromWidget(for: mac.value)
        sut.setLastOpenedChart(with: "chart-1")
        sut.setKeepConnectionDialogWasShown(true, for: luid)
        sut.setFirmwareUpdateDialogWasShown(true, for: luid)
        sut.setOwnerCheckDate(for: mac, value: ownerCheckDate)
        sut.setShowCustomTempAlertBound(true, for: "sensor-id")

        wait(for: [languageChanged], timeout: 1)
        XCTAssertEqual(sut.language, .finnish)
        XCTAssertEqual(sut.cardToOpenFromWidget(), mac.value)
        XCTAssertEqual(sut.lastOpenedChart(), "chart-1")
        XCTAssertTrue(sut.keepConnectionDialogWasShown(for: luid))
        XCTAssertTrue(sut.firmwareUpdateDialogWasShown(for: luid))
        XCTAssertEqual(sut.ownerCheckDate(for: mac), ownerCheckDate)
        XCTAssertTrue(sut.showCustomTempAlertBound(for: "sensor-id"))

        sut.setCardToOpenFromWidget(for: nil)
        sut.setLastOpenedChart(with: nil)
        sut.setOwnerCheckDate(for: mac, value: nil)
        XCTAssertNil(sut.cardToOpenFromWidget())
        XCTAssertNil(sut.lastOpenedChart())
        XCTAssertNil(sut.ownerCheckDate(for: mac))
        XCTAssertEqual(
            UserDefaults(suiteName: "group.com.ruuvi.station.pnservice")?
                .string(forKey: "SettingsUserDegaults.languageUDKey"),
            Language.finnish.rawValue
        )
    }

    func testSettingsPersistUnitsDashboardChoicesAndFeatureFlags() {
        let sut = RuuviLocalSettingsUserDefaults()
        let mac = "AA:BB:CC:11:22:33".mac

        XCTAssertTrue(sut.dashboardSensorOrder.isEmpty)
        XCTAssertFalse(sut.showCustomTempAlertBound(for: "missing-sensor"))
        XCTAssertFalse(sut.dashboardSignInBannerHidden(for: "0.0.0"))

        sut.humidityUnit = .gm3
        sut.humidityAccuracy = .one
        sut.temperatureUnit = .kelvin
        sut.temperatureAccuracy = .zero
        sut.pressureUnit = .inchesOfMercury
        sut.pressureAccuracy = .one
        sut.welcomeShown = true
        sut.showGraphLongPressTutorial = false
        sut.tosAccepted = true
        sut.analyticsConsentGiven = true
        sut.tagChartsLandscapeSwipeInstructionWasShown = true
        sut.cardsSwipeHintWasShown = true
        sut.isAdvertisementDaemonOn = false
        sut.connectionTimeout = 45
        sut.serviceTimeout = 90
        sut.advertisementDaemonIntervalMinutes = 2
        sut.alertsMuteIntervalMinutes = 30
        sut.movementAlertHysteresisMinutes = 7
        sut.saveHeartbeats = false
        sut.saveHeartbeatsIntervalMinutes = 10
        sut.saveHeartbeatsForegroundIntervalSeconds = 5
        sut.webPullIntervalMinutes = 20
        sut.dataPruningOffsetHours = 300
        sut.chartIntervalSeconds = 600
        sut.chartDurationHours = 12
        sut.networkPullIntervalSeconds = 120
        sut.widgetRefreshIntervalMinutes = 10
        sut.forceRefreshWidget = true
        sut.networkPruningIntervalHours = 72
        sut.chartDownsamplingOn = true
        sut.chartShowAllMeasurements = true
        sut.chartDrawDotsOn = true
        sut.chartStatsOn = false
        sut.chartShowAll = false
        sut.experimentalFeaturesEnabled = true
        sut.cloudModeEnabled = true
        sut.useSimpleWidget = false
        sut.appIsOnForeground = true
        sut.appOpenedCount = 3
        sut.appOpenedInitialCountToAskReview = 10
        sut.appOpenedCountDivisibleToAskReview = 25
        sut.dashboardEnabled = false
        sut.dashboardType = .simple
        sut.dashboardTapActionType = .chart
        sut.showFullSensorCardOnDashboardTap = false
        sut.dashboardSensorOrder = ["sensor-1", "sensor-2"]
        sut.theme = .dark
        sut.hideNFCForSensorContest = true
        sut.alertSound = .systemDefault
        sut.emailAlertDisabled = true
        sut.pushAlertDisabled = true
        sut.marketingPreference = true
        sut.limitAlertNotificationsEnabled = false
        sut.showSwitchStatusLabel = false
        sut.customTempAlertLowerBound = -10
        sut.customTempAlertUpperBound = 50
        sut.showAlertsRangeInGraph = false
        sut.useNewGraphRendering = true
        sut.imageCompressionQuality = 80
        sut.compactChartView = false
        sut.historySyncLegacy = true
        sut.historySyncOnDashboard = true
        sut.historySyncForEachSensor = false
        sut.includeDataSourceInHistoryExport = true
        sut.setLedBrightnessSelection(.bright, for: mac)
        sut.setNotificationsBadgeCount(value: 7)
        sut.setDashboardSignInBannerHidden(for: "1.0.0")

        let reloaded = RuuviLocalSettingsUserDefaults()

        XCTAssertEqual(reloaded.humidityUnit, .gm3)
        XCTAssertEqual(reloaded.humidityAccuracy, .one)
        XCTAssertEqual(reloaded.temperatureUnit, .kelvin)
        XCTAssertEqual(reloaded.temperatureAccuracy, .zero)
        XCTAssertEqual(reloaded.pressureUnit, .inchesOfMercury)
        XCTAssertEqual(reloaded.pressureAccuracy, .one)
        XCTAssertTrue(reloaded.welcomeShown)
        XCTAssertFalse(reloaded.showGraphLongPressTutorial)
        XCTAssertTrue(reloaded.tosAccepted)
        XCTAssertTrue(reloaded.analyticsConsentGiven)
        XCTAssertTrue(reloaded.tagChartsLandscapeSwipeInstructionWasShown)
        XCTAssertTrue(reloaded.cardsSwipeHintWasShown)
        XCTAssertFalse(reloaded.isAdvertisementDaemonOn)
        XCTAssertEqual(reloaded.connectionTimeout, 45)
        XCTAssertEqual(reloaded.serviceTimeout, 90)
        XCTAssertEqual(reloaded.advertisementDaemonIntervalMinutes, 2)
        XCTAssertEqual(reloaded.alertsMuteIntervalMinutes, 30)
        XCTAssertEqual(reloaded.movementAlertHysteresisMinutes, 7)
        XCTAssertFalse(reloaded.saveHeartbeats)
        XCTAssertEqual(reloaded.saveHeartbeatsIntervalMinutes, 10)
        XCTAssertEqual(reloaded.saveHeartbeatsForegroundIntervalSeconds, 5)
        XCTAssertEqual(reloaded.webPullIntervalMinutes, 20)
        XCTAssertEqual(reloaded.dataPruningOffsetHours, 300)
        XCTAssertEqual(reloaded.chartIntervalSeconds, 600)
        XCTAssertEqual(reloaded.chartDurationHours, 12)
        XCTAssertEqual(reloaded.networkPullIntervalSeconds, 120)
        XCTAssertEqual(reloaded.widgetRefreshIntervalMinutes, 10)
        XCTAssertTrue(reloaded.forceRefreshWidget)
        XCTAssertEqual(reloaded.networkPruningIntervalHours, 72)
        XCTAssertTrue(reloaded.chartDownsamplingOn)
        XCTAssertTrue(reloaded.chartShowAllMeasurements)
        XCTAssertTrue(reloaded.chartDrawDotsOn)
        XCTAssertFalse(reloaded.chartStatsOn)
        XCTAssertFalse(reloaded.chartShowAll)
        XCTAssertTrue(reloaded.experimentalFeaturesEnabled)
        XCTAssertTrue(reloaded.cloudModeEnabled)
        XCTAssertFalse(reloaded.useSimpleWidget)
        XCTAssertTrue(reloaded.appIsOnForeground)
        XCTAssertEqual(reloaded.appOpenedCount, 3)
        XCTAssertEqual(reloaded.appOpenedInitialCountToAskReview, 10)
        XCTAssertEqual(reloaded.appOpenedCountDivisibleToAskReview, 25)
        XCTAssertFalse(reloaded.dashboardEnabled)
        XCTAssertEqual(reloaded.dashboardType, .simple)
        XCTAssertEqual(reloaded.dashboardTapActionType, .chart)
        XCTAssertFalse(reloaded.showFullSensorCardOnDashboardTap)
        XCTAssertEqual(reloaded.dashboardSensorOrder, ["sensor-1", "sensor-2"])
        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertTrue(reloaded.hideNFCForSensorContest)
        XCTAssertEqual(reloaded.alertSound, .systemDefault)
        XCTAssertTrue(reloaded.emailAlertDisabled)
        XCTAssertTrue(reloaded.pushAlertDisabled)
        XCTAssertTrue(reloaded.marketingPreference)
        XCTAssertFalse(reloaded.limitAlertNotificationsEnabled)
        XCTAssertFalse(reloaded.showSwitchStatusLabel)
        XCTAssertEqual(reloaded.customTempAlertLowerBound, -10)
        XCTAssertEqual(reloaded.customTempAlertUpperBound, 50)
        XCTAssertFalse(reloaded.showAlertsRangeInGraph)
        XCTAssertTrue(reloaded.useNewGraphRendering)
        XCTAssertEqual(reloaded.imageCompressionQuality, 80)
        XCTAssertFalse(reloaded.compactChartView)
        XCTAssertTrue(reloaded.historySyncLegacy)
        XCTAssertTrue(reloaded.historySyncOnDashboard)
        XCTAssertFalse(reloaded.historySyncForEachSensor)
        XCTAssertTrue(reloaded.includeDataSourceInHistoryExport)
        XCTAssertEqual(reloaded.ledBrightnessSelection(for: mac), .bright)
        XCTAssertEqual(reloaded.notificationsBadgeCount(), 7)
        XCTAssertTrue(reloaded.dashboardSignInBannerHidden(for: "1.0.0"))

        reloaded.setLedBrightnessSelection(nil, for: mac)
        XCTAssertNil(reloaded.ledBrightnessSelection(for: mac))
    }

    func testSettingsResolveLegacyTemperatureDefaultsAndPostAsyncPreferenceNotifications() async {
        let emailChanged = expectation(
            forNotification: .EmailAlertSettingsDidChange,
            object: nil
        )
        let pushChanged = expectation(
            forNotification: .PushAlertSettingsDidChange,
            object: nil
        )
        let marketingChanged = expectation(
            forNotification: .MarketingPreferenceDidChange,
            object: nil
        )
        let limitChanged = expectation(
            forNotification: .LimitAlertNotificationsSettingsDidChange,
            object: nil
        )
        let sut = RuuviLocalSettingsUserDefaults()

        sut.emailAlertDisabled = true
        sut.pushAlertDisabled = true
        sut.marketingPreference = true
        sut.limitAlertNotificationsEnabled = false

        await fulfillment(of: [emailChanged, pushChanged, marketingChanged, limitChanged], timeout: 1)

        resetLocalUserDefaults()
        UserDefaults.standard.set(true, forKey: "SettingsUserDegaults.useFahrenheit")
        XCTAssertEqual(RuuviLocalSettingsUserDefaults().temperatureUnit, .fahrenheit)

        resetLocalUserDefaults()
        UserDefaults.standard.set(1, forKey: "SettingsUserDefaults.appOpenedCount")
        XCTAssertEqual(RuuviLocalSettingsUserDefaults().temperatureUnit, .celsius)

        resetLocalUserDefaults()
        XCTAssertTrue(RuuviLocalSettingsUserDefaults().movementAlertHysteresisLastEvents().isEmpty)
        UserDefaults.standard.set(
            [
                "sensor-a": NSNumber(value: 1_700_000_000),
                "sensor-b": TimeInterval(1_700_000_100),
            ],
            forKey: "SettingsUserDefaults.movementAlertHysteresisLastEvents"
        )
        let events = RuuviLocalSettingsUserDefaults().movementAlertHysteresisLastEvents()
        XCTAssertEqual(events["sensor-a"], Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(events["sensor-b"], Date(timeIntervalSince1970: 1_700_000_100))
    }

    func testSettingsCoverEnumDefaultsLegacyBranchesAndPerSensorMetadata() {
        var sut = RuuviLocalSettingsUserDefaults()
        let luid = UUID().uuidString.luid
        let mac = "AA:BB:CC:11:22:33".mac
        let date = Date(timeIntervalSince1970: 1_700_001_000)

        XCTAssertEqual(sut.language, .english)
        XCTAssertEqual(sut.alertSound, .ruuviSpeak)
        sut.setFirmwareVersion(for: luid, value: "1.2.3")
        XCTAssertEqual(sut.firmwareVersion(for: luid), "1.2.3")
        sut.setFirmwareVersion(for: luid, value: nil)
        XCTAssertNil(sut.firmwareVersion(for: luid))
        sut.setMovementAlertHysteresisLastEvents(["sensor-a": date])
        XCTAssertEqual(sut.movementAlertHysteresisLastEvents()["sensor-a"], date)
        sut.setSyncDialogHidden(true, for: luid)
        XCTAssertTrue(sut.syncDialogHidden(for: luid))

        sut.humidityUnit = .percent
        XCTAssertEqual(sut.humidityUnit, .percent)
        sut.humidityUnit = .dew
        XCTAssertEqual(sut.humidityUnit, .dew)

        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.humidityAccuracyInt")
        XCTAssertEqual(sut.humidityAccuracy, .two)
        sut.humidityAccuracy = .zero
        XCTAssertEqual(sut.humidityAccuracy, .zero)
        sut.humidityAccuracy = .two
        XCTAssertEqual(sut.humidityAccuracy, .two)

        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.temperatureAccuracyInt")
        XCTAssertEqual(sut.temperatureAccuracy, .two)
        sut.temperatureAccuracy = .zero
        XCTAssertEqual(sut.temperatureAccuracy, .zero)
        sut.temperatureAccuracy = .one
        XCTAssertEqual(sut.temperatureAccuracy, .one)
        sut.temperatureAccuracy = .two
        XCTAssertEqual(sut.temperatureAccuracy, .two)

        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.pressureAccuracyInt")
        XCTAssertEqual(sut.pressureAccuracy, .two)
        sut.pressureAccuracy = .zero
        XCTAssertEqual(sut.pressureAccuracy, .zero)
        sut.pressureAccuracy = .two
        XCTAssertEqual(sut.pressureAccuracy, .two)

        sut.temperatureUnit = .celsius
        XCTAssertEqual(sut.temperatureUnit, .celsius)
        sut.temperatureUnit = .fahrenheit
        XCTAssertEqual(sut.temperatureUnit, .fahrenheit)

        resetLocalUserDefaults()
        UserDefaults.standard.set("K", forKey: "AppleTemperatureUnit")
        sut = RuuviLocalSettingsUserDefaults()
        XCTAssertEqual(sut.temperatureUnit, .kelvin)

        resetLocalUserDefaults()
        UserDefaults.standard.set(99, forKey: "SettingsUserDegaults.temperatureUnitIntUDKey")
        sut = RuuviLocalSettingsUserDefaults()
        XCTAssertEqual(sut.temperatureUnit, .celsius)

        sut.pressureUnit = .newtonsPerMetersSquared
        XCTAssertEqual(sut.pressureUnit, .newtonsPerMetersSquared)
        sut.pressureUnit = .millimetersOfMercury
        XCTAssertEqual(sut.pressureUnit, .millimetersOfMercury)
        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.pressureUnitInt")
        XCTAssertEqual(sut.pressureUnit, .hectopascals)

        sut.setLedBrightnessSelection(.off, for: mac)
        XCTAssertEqual(sut.ledBrightnessSelection(for: mac), .off)
        sut.setLedBrightnessSelection(.dim, for: mac)
        XCTAssertEqual(sut.ledBrightnessSelection(for: mac), .dim)
        sut.setLedBrightnessSelection(.normal, for: mac)
        XCTAssertEqual(sut.ledBrightnessSelection(for: mac), .normal)
        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.ledBrightnessSelection.\(mac.mac)")
        XCTAssertNil(sut.ledBrightnessSelection(for: mac))

        sut.dashboardType = .image
        XCTAssertEqual(sut.dashboardType, .image)
        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.dashboardTypeIdKey")
        XCTAssertEqual(sut.dashboardType, .image)
        sut.dashboardTapActionType = .card
        XCTAssertEqual(sut.dashboardTapActionType, .card)
        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.dashboardTapActionTypeIdKey")
        XCTAssertEqual(sut.dashboardTapActionType, .card)

        sut.theme = .system
        XCTAssertEqual(sut.theme, .system)
        sut.theme = .light
        XCTAssertEqual(sut.theme, .light)
        UserDefaults.standard.set(99, forKey: "SettingsUserDefaults.ruuviThemeIdKey")
        XCTAssertEqual(sut.theme, .system)

        resetLocalUserDefaults()
        UserDefaults(suiteName: "group.com.ruuvi.station.pnservice")?
            .set("unknown", forKey: "SettingsUserDegaults.languageUDKey")
        XCTAssertEqual(RuuviLocalSettingsUserDefaults().language, .english)

        resetLocalUserDefaults()
        UserDefaults.standard.set("unknown", forKey: "SettingsUserDefaults.ruuviAlertSoundKey")
        XCTAssertEqual(RuuviLocalSettingsUserDefaults().alertSound, .ruuviSpeak)
    }

    func testFlagsExposeDefaultsAndPersistOverrides() {
        let sut = RuuviLocalFlagsUserDefaults()

        XCTAssertFalse(sut.showNewCardsMenu)
        XCTAssertTrue(sut.autoSyncGattHistoryForRuuviAir)
        XCTAssertEqual(sut.autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes, 5)
        XCTAssertEqual(sut.graphDownsampleMaximumPoints, 3000)

        sut.showDashboardSensorSearch = true
        sut.graphDownsampleMaximumPoints = 1024

        let reloaded = RuuviLocalFlagsUserDefaults()
        XCTAssertTrue(reloaded.showDashboardSensorSearch)
        XCTAssertEqual(reloaded.graphDownsampleMaximumPoints, 1024)
    }

    func testLocalImagesTracksCustomBackgroundProgressAndCloudPictureCache() async throws {
        let persistence = ImagePersistenceSpy()
        let sut = RuuviLocalImagesUserDefaults(imagePersistence: persistence)
        let sensor = makeSensor(macId: "AA:BB:CC:11:22:33")
        let sensorMacValue = sensor.macId?.value
        let cloudSensor = makeCloudSensor(id: sensor.id, picture: URL(string: "https://example.com/bg.png"))
        let image = makeImage(color: .black)
        let backgroundChanged = expectation(
            forNotification: .BackgroundPersistenceDidChangeBackground,
            object: nil
        ) { note in
            let macId = note.userInfo?[BPDidChangeBackgroundKey.macId] as? MACIdentifier
            return macId?.value == sensorMacValue
        }
        let progressChanged = expectation(
            forNotification: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
            object: nil
        ) { note in
            let macId = note.userInfo?[BPDidUpdateBackgroundUploadProgressKey.macId] as? MACIdentifier
            let progress = note.userInfo?[BPDidUpdateBackgroundUploadProgressKey.progress] as? Double
            return macId?.value == sensorMacValue && progress == 0.25
        }

        let url = try await sut.setCustomBackground(
            image: image,
            compressionQuality: 0.8,
            for: sensor.macId!
        )
        sut.setBackgroundUploadProgress(percentage: 0.25, for: sensor.macId!)
        sut.setPictureIsCached(for: cloudSensor)

        await fulfillment(of: [backgroundChanged, progressChanged], timeout: 1)
        XCTAssertEqual(url, persistence.nextURL)
        XCTAssertEqual(sut.getCustomBackground(for: sensor.macId!)?.pngData(), image.pngData())
        XCTAssertEqual(sut.backgroundUploadProgress(for: sensor.macId!), 0.25)
        XCTAssertTrue(sut.isPictureCached(for: cloudSensor))

        sut.deleteBackgroundUploadProgress(for: sensor.macId!)
        sut.setPictureRemovedFromCache(for: sensor)

        XCTAssertNil(sut.backgroundUploadProgress(for: sensor.macId!))
        XCTAssertFalse(sut.isPictureCached(for: cloudSensor))
    }

    func testLocalImagesDefaultBackgroundSelectionGenerationAndRemovalUseStableSlots() async throws {
        let persistence = ImagePersistenceSpy()
        let sut = RuuviLocalImagesUserDefaults(imagePersistence: persistence)
        let luid = UUID().uuidString.luid
        let sensor = makeSensor(luid: luid.value, macId: "AA:BB:CC:11:22:33")
        let cloudSensor = makeCloudSensor(
            id: sensor.id,
            picture: URL(string: "https://example.com/picture.png")
        )
        let backgroundChanged = expectation(
            forNotification: .BackgroundPersistenceDidChangeBackground,
            object: nil
        ) { note in
            let observedLuid = note.userInfo?[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
            return observedLuid?.value == luid.value
        }

        _ = try await sut.setCustomBackground(
            image: makeImage(color: .blue),
            compressionQuality: 0.8,
            for: luid
        )

        await fulfillment(of: [backgroundChanged], timeout: 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: backgroundKey(for: luid)), 0)
        XCTAssertNotNil(sut.getCustomBackground(for: luid))

        _ = sut.setNextDefaultBackground(for: luid)
        let firstDefault = UserDefaults.standard.integer(forKey: backgroundKey(for: luid))
        XCTAssertTrue((1...17).contains(firstDefault))
        XCTAssertNil(sut.getCustomBackground(for: luid))

        _ = sut.setNextDefaultBackground(for: luid)
        let expectedNext = firstDefault == 17 ? 1 : firstDefault + 1
        XCTAssertEqual(UserDefaults.standard.integer(forKey: backgroundKey(for: luid)), expectedNext)

        let ruuviTagIdentifier = UUID().uuidString.luid
        let ruuviAirIdentifier = UUID().uuidString.luid
        _ = sut.getOrGenerateBackground(for: ruuviTagIdentifier, ruuviDeviceType: .ruuviTag)
        _ = sut.getOrGenerateBackground(for: ruuviAirIdentifier, ruuviDeviceType: .ruuviAir)

        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: backgroundKey(for: ruuviTagIdentifier)),
            16
        )
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: backgroundKey(for: ruuviAirIdentifier)),
            17
        )

        sut.setBackground(5, for: sensor.macId!)
        sut.setBackground(6, for: sensor.luid!)
        sut.setPictureIsCached(for: cloudSensor)
        sut.setPictureRemovedFromCache(for: sensor)

        XCTAssertNil(UserDefaults.standard.object(forKey: backgroundKey(for: sensor.macId!)))
        XCTAssertNil(UserDefaults.standard.object(forKey: backgroundKey(for: sensor.luid!)))
        XCTAssertFalse(sut.isPictureCached(for: cloudSensor))
    }

    func testLocalImagesReadExplicitBackgroundsAndDeleteCustomImage() async throws {
        let persistence = ImagePersistenceSpy()
        let sut = RuuviLocalImagesUserDefaults(imagePersistence: persistence)
        let luid = UUID().uuidString.luid
        let customImage = makeImage(color: .green)

        _ = try await sut.setCustomBackground(
            image: customImage,
            compressionQuality: 0.7,
            for: luid
        )

        XCTAssertEqual(UserDefaults.standard.integer(forKey: backgroundKey(for: luid)), 0)
        XCTAssertEqual(sut.getBackground(for: luid)?.pngData(), customImage.pngData())
        XCTAssertEqual(
            sut.getOrGenerateBackground(for: luid, ruuviDeviceType: .ruuviTag)?.pngData(),
            customImage.pngData()
        )

        sut.deleteCustomBackground(for: luid)
        XCTAssertEqual(persistence.deletedIdentifiers, [luid.value])
        XCTAssertNil(sut.getCustomBackground(for: luid))

        sut.setBackground(1, for: luid)
        _ = sut.getBackground(for: luid)
        _ = sut.getOrGenerateBackground(for: luid, ruuviDeviceType: .ruuviAir)
        _ = sut.setNextDefaultBackground(for: luid)

        XCTAssertEqual(UserDefaults.standard.integer(forKey: backgroundKey(for: luid)), 2)
        XCTAssertEqual(persistence.deletedIdentifiers, [luid.value, luid.value])

        sut.setBackground(17, for: luid)
        _ = sut.setNextDefaultBackground(for: luid)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: backgroundKey(for: luid)), 1)

        let progressChanged = expectation(
            forNotification: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
            object: nil
        ) { note in
            let observedLuid = note.userInfo?[BPDidUpdateBackgroundUploadProgressKey.luid] as? LocalIdentifier
            let progress = note.userInfo?[BPDidUpdateBackgroundUploadProgressKey.progress] as? Double
            return observedLuid?.value == luid.value && progress == 0.75
        }

        sut.setBackgroundUploadProgress(percentage: 0.75, for: luid)

        await fulfillment(of: [progressChanged], timeout: 1)
        XCTAssertEqual(sut.backgroundUploadProgress(for: luid), 0.75)
    }

    func testFactoryCreatesExpectedConcreteTypes() {
        let sut = RuuviLocalFactoryUserDefaults()

        XCTAssertTrue(sut.createLocalFlags() is RuuviLocalFlagsUserDefaults)
        XCTAssertTrue(sut.createLocalSettings() is RuuviLocalSettingsUserDefaults)
        XCTAssertTrue(sut.createLocalIDs() is RuuviLocalIDsUserDefaults)
        XCTAssertTrue(sut.createLocalConnections() is RuuviLocalConnectionsUserDefaults)
        XCTAssertTrue(sut.createLocalSyncState() is RuuviLocalSyncStateUserDefaults)
        XCTAssertTrue(sut.createLocalImages() is RuuviLocalImagesUserDefaults)
    }

    func testWidgetSensorSnapshotMatchesAnyStableIdentifier() {
        let settings = WidgetSensorSettingsSnapshot(
            temperatureOffset: 1,
            humidityOffset: 2,
            pressureOffset: 3,
            displayOrder: ["temperature", "humidity"],
            defaultDisplayOrder: false
        )
        let snapshot = WidgetSensorSnapshot(
            id: "sensor-id",
            name: "Widget",
            macId: "AA:BB:CC:11:22:33",
            luid: "widget-luid",
            record: nil,
            settings: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let sensor = makeSensor(luid: "widget-luid", macId: "AA:BB:CC:11:22:33")

        XCTAssertTrue(snapshot.matches(identifier: "sensor-id"))
        XCTAssertTrue(snapshot.matches(identifier: "AA:BB:CC:11:22:33"))
        XCTAssertTrue(snapshot.matches(identifier: "widget-luid"))
        XCTAssertFalse(snapshot.matches(identifier: "different"))
        XCTAssertTrue(snapshot.matches(sensor: sensor.any))
        XCTAssertEqual(settings.displayOrder, ["temperature", "humidity"])
        XCTAssertEqual(settings.defaultDisplayOrder, false)

        let (cache, defaults, suiteName) = makeWidgetCache()
        cache.upsert(sensor: sensor.any, record: nil, settings: nil)
        XCTAssertNil(cache.snapshot(matching: "different"))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testWidgetSensorCacheUpsertMatchesByMacAndPreservesExistingRecordAndSettings() {
        let (sut, defaults, suiteName) = makeWidgetCache()
        let originalSensor = makeSensor(luid: "original-luid", macId: "AA:BB:CC:11:22:33")
        let replacementSensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.1",
            luid: originalSensor.luid,
            macId: originalSensor.macId,
            serviceUUID: nil,
            isConnectable: true,
            name: "",
            isClaimed: false,
            isOwner: false,
            owner: nil,
            ownersPlan: nil,
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil,
            lastUpdated: nil
        )
        let originalRecord = WidgetSensorRecordSnapshot(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            source: RuuviTagSensorRecordSource.advertisement.rawValue,
            macId: originalSensor.macId?.value,
            luid: originalSensor.luid?.value,
            rssi: -65,
            version: 5,
            temperature: 21,
            humidity: 52,
            pressure: 1001,
            accelerationX: nil,
            accelerationY: nil,
            accelerationZ: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: 1,
            txPower: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminance: nil,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0,
            humidityOffset: 0,
            pressureOffset: 0
        )
        let originalSettings = SensorSettingsStruct(
            luid: originalSensor.luid,
            macId: originalSensor.macId,
            temperatureOffset: 1.5,
            humidityOffset: 2,
            pressureOffset: 3
        )

        sut.upsert(sensor: originalSensor.any, record: originalRecord, settings: originalSettings)
        sut.upsert(sensor: replacementSensor.any, record: nil, settings: nil)

        let snapshots = sut.loadAll()
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.id, replacementSensor.id)
        XCTAssertEqual(snapshots.first?.name, replacementSensor.id)
        XCTAssertEqual(snapshots.first?.record, originalRecord)
        XCTAssertEqual(snapshots.first?.settings, WidgetSensorSettingsSnapshot(settings: originalSettings))

        let replacementRecord = makeWidgetRecord(
            for: replacementSensor,
            date: Date(timeIntervalSince1970: 1_700_000_100),
            source: .ruuviNetwork,
            sequence: 2
        )
        let replacementSettings = SensorSettingsStruct(
            luid: replacementSensor.luid,
            macId: replacementSensor.macId,
            temperatureOffset: 2,
            humidityOffset: 3,
            pressureOffset: 4,
            displayOrder: ["pressure"],
            defaultDisplayOrder: true
        )

        sut.upsert(sensor: replacementSensor.any, record: replacementRecord, settings: replacementSettings)

        let replaced = sut.loadAll().first
        XCTAssertEqual(replaced?.record, replacementRecord)
        XCTAssertEqual(replaced?.settings, WidgetSensorSettingsSnapshot(settings: replacementSettings))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testWidgetSensorCacheSyncSensorsCanInsertNewSensorWithDefaultLookup() {
        let (sut, defaults, suiteName) = makeWidgetCache()
        let sensor = makeSensor(luid: "new-luid", macId: "AA:BB:CC:22:33:44")

        sut.syncSensors([sensor.any])

        let snapshots = sut.loadAll()
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.id, sensor.id)
        XCTAssertEqual(snapshots.first?.name, sensor.name)
        XCTAssertEqual(snapshots.first?.macId, sensor.macId?.value)
        XCTAssertEqual(snapshots.first?.luid, sensor.luid?.value)
        XCTAssertNil(snapshots.first?.record)
        XCTAssertNil(snapshots.first?.settings)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testWidgetSensorCacheSyncSensorsReplacesMissingEntriesAndAppliesSettingsLookup() {
        let (sut, defaults, suiteName) = makeWidgetCache()
        let keptSensor = makeSensor(luid: "kept-luid", macId: "AA:BB:CC:11:22:33")
        let removedSensor = makeSensor(luid: "removed-luid", macId: "AA:BB:CC:44:55:66")
        let record = WidgetSensorRecordSnapshot(
            date: Date(timeIntervalSince1970: 1_700_000_010),
            source: RuuviTagSensorRecordSource.advertisement.rawValue,
            macId: keptSensor.macId?.value,
            luid: keptSensor.luid?.value,
            rssi: -70,
            version: 5,
            temperature: 19,
            humidity: 48,
            pressure: 998,
            accelerationX: nil,
            accelerationY: nil,
            accelerationZ: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: 2,
            txPower: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminance: nil,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0,
            humidityOffset: 0,
            pressureOffset: 0
        )
        sut.upsert(sensor: keptSensor.any, record: record, settings: nil)
        sut.upsert(sensor: removedSensor.any, record: nil, settings: nil)

        let keptSettings = SensorSettingsStruct(
            luid: keptSensor.luid,
            macId: keptSensor.macId,
            temperatureOffset: 0.5,
            humidityOffset: nil,
            pressureOffset: nil
        )

        sut.syncSensors([keptSensor.any]) { sensor in
            sensor.id == keptSensor.id ? keptSettings : nil
        }

        let snapshots = sut.loadAll()
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.id, keptSensor.id)
        XCTAssertEqual(snapshots.first?.record, record)
        XCTAssertEqual(snapshots.first?.settings, WidgetSensorSettingsSnapshot(settings: keptSettings))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testWidgetSensorCachePruneKeepsSnapshotsMatchedByMacOrLuid() {
        let (sut, defaults, suiteName) = makeWidgetCache()
        let first = makeSensor(luid: "luid-1", macId: "AA:BB:CC:11:22:33")
        let second = makeSensor(luid: "luid-2", macId: "AA:BB:CC:44:55:66")
        let third = makeSensor(luid: "luid-3", macId: "AA:BB:CC:77:88:99")
        sut.upsert(sensor: first.any, record: nil, settings: nil)
        sut.upsert(sensor: second.any, record: nil, settings: nil)
        sut.upsert(sensor: third.any, record: nil, settings: nil)

        sut.prune(keeping: [first.luid!.value, second.macId!.value])

        let snapshots = sut.loadAll()
        XCTAssertEqual(snapshots.map(\.id).sorted(), [first.id, second.id].sorted())
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testWidgetSensorCacheReturnsEmptySnapshotsWhenStoredPayloadIsCorrupted() {
        let suiteName = "RuuviLocal.WidgetSensorCache.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "RuuviWidgetSensorCache.v1")
        let sut = WidgetSensorCache(userDefaults: defaults)

        XCTAssertTrue(sut.loadAll().isEmpty)
        XCTAssertNil(sut.snapshot(matching: "sensor-id"))
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private func resetLocalUserDefaults() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
    if let appGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice") {
        for key in appGroup.dictionaryRepresentation().keys {
            appGroup.removeObject(forKey: key)
        }
    }
}

private func makeSensor(
    luid: String = UUID().uuidString,
    macId: String
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: luid.luid,
        macId: macId.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: "Sensor",
        isClaimed: false,
        isOwner: false,
        owner: nil,
        ownersPlan: nil,
        isCloudSensor: true,
        canShare: false,
        sharedTo: [],
        maxHistoryDays: nil,
        lastUpdated: nil
    )
}

private func makeCloudSensor(id: String, picture: URL?) -> CloudSensor {
    CloudSensorStruct(
        id: id,
        serviceUUID: nil,
        name: "Cloud sensor",
        isClaimed: true,
        isOwner: true,
        owner: "owner@example.com",
        ownersPlan: nil,
        picture: picture,
        offsetTemperature: nil,
        offsetHumidity: nil,
        offsetPressure: nil,
        isCloudSensor: true,
        canShare: true,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private func makeWidgetRecord(
    for sensor: RuuviTagSensor,
    date: Date,
    source: RuuviTagSensorRecordSource,
    sequence: Int
) -> WidgetSensorRecordSnapshot {
    WidgetSensorRecordSnapshot(
        date: date,
        source: source.rawValue,
        macId: sensor.macId?.value,
        luid: sensor.luid?.value,
        rssi: -60,
        version: 5,
        temperature: 22,
        humidity: 50,
        pressure: 1002,
        accelerationX: nil,
        accelerationY: nil,
        accelerationZ: nil,
        voltage: nil,
        movementCounter: nil,
        measurementSequenceNumber: sequence,
        txPower: nil,
        pm1: nil,
        pm25: nil,
        pm4: nil,
        pm10: nil,
        co2: nil,
        voc: nil,
        nox: nil,
        luminance: nil,
        dbaInstant: nil,
        dbaAvg: nil,
        dbaPeak: nil,
        temperatureOffset: 0,
        humidityOffset: 0,
        pressureOffset: 0
    )
}

private func makeImage(color: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
    return renderer.image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    }
}

private struct OptionalValueBox {
    static let key = "RuuviLocalTests.optional.key"

    @UserDefault(key, defaultValue: nil)
    var value: String?
}

private final class ImagePersistenceSpy: ImagePersistence {
    let nextURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("local-bg.png")
    private(set) var deletedIdentifiers: [String] = []
    private var storedImages: [String: UIImage] = [:]

    func fetchBg(for identifier: Identifier) -> UIImage? {
        storedImages[identifier.value]
    }

    func deleteBgIfExists(for identifier: Identifier) {
        deletedIdentifiers.append(identifier.value)
        storedImages[identifier.value] = nil
    }

    func persistBg(
        image: UIImage,
        compressionQuality _: CGFloat,
        for identifier: Identifier
    ) async throws -> URL {
        storedImages[identifier.value] = image
        return nextURL
    }
}

private func makeWidgetCache() -> (WidgetSensorCache, UserDefaults, String) {
    let suiteName = "RuuviLocal.WidgetSensorCache.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (WidgetSensorCache(userDefaults: defaults), defaults, suiteName)
}

private func backgroundKey(for identifier: Identifier) -> String {
    "BackgroundPersistenceUserDefaults.background.\(identifier.value)"
}
