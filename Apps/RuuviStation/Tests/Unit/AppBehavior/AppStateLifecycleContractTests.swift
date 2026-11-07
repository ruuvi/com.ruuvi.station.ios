import RuuviAnalytics
import RuuviDaemon
import RuuviLocal
import RuuviOntology
import RuuviService
import UIKit
import XCTest
@testable import station

@MainActor final class AppStateLifecycleContractTests: XCTestCase {
    func testCloudSyncStartsOnlyForAnAuthorizedForegroundSessionAndDoesNotStartTwice() {
        for authorized in [false, true] {
            for foreground in [false, true] {
                let fixture = AppLifecycleFixture()
                fixture.user.isAuthorized = authorized
                fixture.settings.appIsOnForeground = foreground
                fixture.settings.setCardToOpenFromWidget(for: "AA:BB:CC:DD:EE:FF")
                fixture.service.applicationDidBecomeActive(.shared)
                fixture.service.applicationDidBecomeActive(.shared)
                XCTAssertEqual(fixture.cloud.starts, authorized && foreground ? 1 : 0)
                XCTAssertEqual(fixture.links.widgets, ["AA:BB:CC:DD:EE:FF", "AA:BB:CC:DD:EE:FF"])
            }
        }
    }

    func testBackgroundAndForegroundPreserveScanningPreferenceAndResetOnlyGattSuppression() {
        for scanning in [false, true] {
            for authorized in [false, true] {
                let fixture = AppLifecycleFixture()
                fixture.settings.isAdvertisementDaemonOn = scanning
                fixture.user.isAuthorized = authorized
                let mac = "AA:BB:CC:DD:EE:FF".mac
                let date = Date(timeIntervalSince1970: 100)
                fixture.sync.setAutoGattSyncSuppressed(true, for: mac)
                fixture.sync.setGattSyncDate(date, for: mac)
                fixture.group.set(false, forKey: AppGroupConstants.forceRefreshWidgetKey)
                fixture.service.applicationDidEnterBackground(.shared)
                XCTAssertEqual(fixture.group.bool(forKey: AppGroupConstants.forceRefreshWidgetKey), authorized)
                XCTAssertFalse(fixture.settings.appIsOnForeground)
                XCTAssertEqual(fixture.advertisements.stops, scanning ? 1 : 0)
                XCTAssertEqual(fixture.cloud.stops, authorized ? 1 : 0)
                XCTAssertEqual(fixture.properties.stops, 1)
                XCTAssertEqual(fixture.background.schedules, 1)
                XCTAssertTrue(fixture.sync.isAutoGattSyncSuppressed(for: mac))
                fixture.service.applicationWillEnterForeground(.shared)
                XCTAssertTrue(fixture.settings.appIsOnForeground)
                XCTAssertEqual(fixture.advertisements.starts, scanning ? 1 : 0)
                XCTAssertEqual(fixture.properties.starts, 1)
                XCTAssertFalse(fixture.sync.isAutoGattSyncSuppressed(for: mac))
                XCTAssertEqual(fixture.sync.getGattSyncDate(for: mac), date)
                XCTAssertEqual(fixture.heartbeat.starts, 0)
            }
        }
    }

    func testLaunchRegistersOncePerLaunchAndLogoutNotificationsPauseAndResumeOnce() async {
        for success in [false, true] {
            for foreground in [false, true] {
                let fixture = AppLifecycleFixture()
                fixture.user.isAuthorized = true
                fixture.settings.isAdvertisementDaemonOn = true
                fixture.service.application(.shared, didFinishLaunchingWithOptions: nil)
                await waitForAppState("analytics updated after launch") { fixture.analytics.updates == 1 }
                XCTAssertEqual(fixture.background.registrations, 1)
                XCTAssertTrue(fixture.settings.signedInAtleastOnce)
                XCTAssertEqual(fixture.settings.appOpenedCount, 1)
                fixture.settings.appIsOnForeground = foreground
                fixture.notifications.post(name: .RuuviAuthServiceWillLogout, object: nil)
                fixture.notifications.post(name: .RuuviAuthServiceWillLogout, object: nil)
                XCTAssertEqual(fixture.advertisements.stops, 1)
                XCTAssertEqual(fixture.heartbeat.stops, 1)
                XCTAssertEqual(fixture.properties.stops, 1)
                XCTAssertEqual(fixture.cloud.stops, 1)
                for _ in 0..<2 {
                    fixture.notifications.post(
                        name: .RuuviAuthServiceLogoutDidFinish, object: nil,
                        userInfo: [RuuviAuthServiceLogoutDidFinishKey.success.rawValue: success])
                }
                XCTAssertEqual(fixture.advertisements.starts, foreground ? 2 : 1)
                XCTAssertEqual(fixture.heartbeat.starts, 2)
                XCTAssertEqual(fixture.properties.starts, foreground ? 2 : 1)
                XCTAssertEqual(fixture.cloud.starts, !success && foreground ? 1 : 0)
            }
        }
    }

    func testLinkCallbacksKeepTheCompleteURLAndWidgetIdentity() {
        let fixture = AppLifecycleFixture()
        let url = URL(string: "https://station.ruuvi.com/verify?token=a%2Bb#verify")!
        fixture.service.applicationDidOpenWithUniversalLink(.shared, url: url)
        fixture.service.applicationDidOpenWithWidgetDeepLink(nil, macId: "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(fixture.links.urls, [url])
        XCTAssertEqual(fixture.links.widgets, ["AA:BB:CC:DD:EE:FF"])
    }
}

@MainActor private final class AppLifecycleFixture {
    let suite = "AppLifecycleContractTests." + UUID().uuidString
    let group: UserDefaults
    let service = AppStateServiceImpl()
    let settings = AppTestSettings()
    let user = DefaultsUserSpy()
    let advertisements = LifecycleDaemonSpy()
    let heartbeat = LifecycleDaemonSpy()
    let properties = LifecycleDaemonSpy()
    let cloud = LifecycleCloudSpy()
    let background = LifecycleBackgroundSpy()
    let analytics = LifecycleAnalyticsSpy()
    let sync = AppSyncStateSpy()
    let links = LifecycleLinksSpy()
    let notifications = NotificationCenter()
    init() {
        group = UserDefaults(suiteName: suite)!
        service.settings = settings; service.ruuviUser = user
        service.advertisementDaemon = advertisements; service.heartbeatDaemon = heartbeat
        service.propertiesDaemon = properties; service.cloudSyncDaemon = cloud
        service.backgroundProcessService = background; service.userPropertiesService = analytics
        service.localSyncState = sync; service.universalLinkCoordinator = links
        service.notificationCenter = notifications
        service.appGroupDefaults = group
    }
    deinit { group.removePersistentDomain(forName: suite) }
}
private final class LifecycleDaemonSpy: RuuviTagAdvertisementDaemon, RuuviTagHeartbeatDaemon, RuuviTagPropertiesDaemon {
    var starts = 0
    var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func restart() { stop(); start() }
}
private final class LifecycleCloudSpy: RuuviDaemonCloudSync {
    var starts = 0
    var stops = 0
    var running = false
    func start() { starts += 1; running = true }
    func stop() { stops += 1; running = false }
    func isRunning() -> Bool { running }
    func refreshImmediately() {}
    func refreshLatestRecord() {}
}
private final class LifecycleBackgroundSpy: BackgroundProcessService {
    var registrations = 0
    var schedules = 0
    func register() { registrations += 1 }
    func schedule() { schedules += 1 }
}
private final class LifecycleAnalyticsSpy: RuuviAnalytics {
    var updates = 0
    func update() { updates += 1 }
    func setConsent(allowed: Bool) { XCTFail("Lifecycle must not change consent") }
}
private final class LifecycleLinksSpy: UniversalLinkCoordinator {
    var urls = [URL]()
    var widgets = [String]()
    func processUniversalLink(url: URL) { urls.append(url) }
    func processWidgetLink(macId: String) { widgets.append(macId) }
}
