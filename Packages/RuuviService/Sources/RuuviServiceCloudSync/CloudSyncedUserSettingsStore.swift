import Foundation
import Future
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

    func readWithFallback() -> Future<[RuuviUserSetting], RuuviServiceError> {
        let promise = Promise<[RuuviUserSetting], RuuviServiceError>()
        storage.readUserSettings()
            .observe(on: .global(qos: .utility))
            .on(success: { [storage, localSettings] storedSettings in
                let syncedSettings = storedSettings.filter {
                    RuuviCloudApiSetting(rawValue: $0.key)?.isCloudSyncedUserSetting == true
                }
                let missingSettings = Self.localFallbackSettings(
                    localSettings: localSettings,
                    excluding: syncedSettings
                )

                guard !missingSettings.isEmpty else {
                    promise.succeed(value: syncedSettings)
                    return
                }

                storage.save(userSettings: missingSettings)
                    .observe(on: .global(qos: .utility))
                    .on(success: { savedSettings in
                        promise.succeed(value: syncedSettings + savedSettings)
                    }, failure: { _ in
                        promise.succeed(value: syncedSettings + missingSettings)
                    })
            }, failure: { [localSettings] _ in
                promise.succeed(value: Self.localFallbackSettings(
                    localSettings: localSettings,
                    excluding: []
                ))
            })
        return promise.future
    }

    func saveSyncedSettings(
        _ settings: [RuuviUserSetting]
    ) -> Future<[RuuviUserSetting], RuuviServiceError> {
        storage.save(userSettings: settings)
            .mapError { .ruuviStorage($0) }
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
