import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology

public final class RuuviServiceAppSettingsImpl: RuuviServiceAppSettings {
    private let cloud: RuuviCloud
    private var localSettings: RuuviLocalSettings

    public init(
        cloud: RuuviCloud,
        localSettings: RuuviLocalSettings
    ) {
        self.cloud = cloud
        self.localSettings = localSettings
    }

    @discardableResult
    public func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit {
        localSettings.temperatureUnit = temperatureUnit
        do {
            return try await cloud.set(temperatureUnit: temperatureUnit)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(
        temperatureAccuracy: MeasurementAccuracyType
    ) async throws -> MeasurementAccuracyType {
        localSettings.temperatureAccuracy = temperatureAccuracy
        do {
            return try await cloud.set(temperatureAccuracy: temperatureAccuracy)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit {
        localSettings.humidityUnit = humidityUnit
        do {
            return try await cloud.set(humidityUnit: humidityUnit)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(
        humidityAccuracy: MeasurementAccuracyType
    ) async throws -> MeasurementAccuracyType {
        localSettings.humidityAccuracy = humidityAccuracy
        do {
            return try await cloud.set(humidityAccuracy: humidityAccuracy)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(pressureUnit: UnitPressure) async throws -> UnitPressure {
        localSettings.pressureUnit = pressureUnit
        do {
            return try await cloud.set(pressureUnit: pressureUnit)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(
        pressureAccuracy: MeasurementAccuracyType
    ) async throws -> MeasurementAccuracyType {
        localSettings.pressureAccuracy = pressureAccuracy
        do {
            return try await cloud.set(pressureAccuracy: pressureAccuracy)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(showAllData: Bool) async throws -> Bool {
        do {
            return try await cloud.set(showAllData: showAllData)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(drawDots: Bool) async throws -> Bool {
        do {
            return try await cloud.set(drawDots: drawDots)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(chartDuration: Int) async throws -> Int {
        do {
            return try await cloud.set(chartDuration: chartDuration)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(showMinMaxAvg: Bool) async throws -> Bool {
        do {
            return try await cloud.set(showMinMaxAvg: showMinMaxAvg)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(cloudMode: Bool) async throws -> Bool {
        do {
            return try await cloud.set(cloudMode: cloudMode)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(dashboard: Bool) async throws -> Bool {
        do {
            return try await cloud.set(dashboard: dashboard)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(dashboardType: DashboardType) async throws -> DashboardType {
        do {
            return try await cloud.set(dashboardType: dashboardType)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        do {
            return try await cloud.set(dashboardTapActionType: dashboardTapActionType)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(disableEmailAlert: Bool) async throws -> Bool {
        do {
            return try await cloud.set(disableEmailAlert: disableEmailAlert)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(disablePushAlert: Bool) async throws -> Bool {
        do {
            return try await cloud.set(disablePushAlert: disablePushAlert)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(profileLanguageCode: String) async throws -> String {
        do {
            return try await cloud.set(profileLanguageCode: profileLanguageCode)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func set(dashboardSensorOrder: [String]) async throws -> [String] {
        do {
            return try await cloud.set(dashboardSensorOrder: dashboardSensorOrder)
        } catch {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }
}
