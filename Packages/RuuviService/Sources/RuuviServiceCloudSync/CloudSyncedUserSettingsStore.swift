#if SWIFT_PACKAGE
    import RuuviService
#endif
import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviStorage

final class CloudSyncedUserSettingsStore {
    private let storage: RuuviStorage
    private let localSettings: RuuviLocalSettings

    init(
        storage: RuuviStorage,
        localSettings: RuuviLocalSettings
    ) {
        self.storage = storage
        self.localSettings = localSettings
    }

    @MainActor
    func readWithFallback() async throws(RuuviServiceError) -> [RuuviUserSetting] {
        guard let storedSettings = try? await storage.readUserSettings() else {
            return Self.localFallbackSettings(localSettings: localSettings, excluding: [])
        }
        let syncedSettings = storedSettings.filter {
            RuuviCloudApiSetting(rawValue: $0.key)?.isCloudSyncedUserSetting == true
        }
        let missingSettings = Self.localFallbackSettings(localSettings: localSettings, excluding: syncedSettings)
        guard !missingSettings.isEmpty else { return syncedSettings }
        let savedSettings = (try? await storage.save(userSettings: missingSettings)) ?? missingSettings
        return syncedSettings + savedSettings
    }

    @MainActor
    func saveSyncedSettings(
        _ settings: [RuuviUserSetting]
    ) async throws(RuuviServiceError) -> [RuuviUserSetting] {
        do { return try await storage.save(userSettings: settings) } catch { throw .ruuviStorage(error) }
    }

    private static func localFallbackSettings(
        localSettings: RuuviLocalSettings,
        excluding storedSettings: [RuuviUserSetting]
    ) -> [RuuviUserSetting] {
        let storedKeys = Set(storedSettings.map(\.key))
        return RuuviCloudApiSetting.cloudSyncedUserSettings.compactMap { setting in
            guard !storedKeys.contains(setting.key) else {
                return nil
            }
            // UserDefaults values have no per-setting timestamp, so migration
            // keeps lastUpdated nil instead of pretending every old value is new.
            return setting.userSetting(from: localSettings)
        }
    }
}
