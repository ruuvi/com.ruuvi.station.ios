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
        return try await RuuviServiceError.perform {
            try await self.cloud.set(temperatureUnit: temperatureUnit)
        }
    }

    @discardableResult
    public func set(
        temperatureAccuracy: MeasurementAccuracyType
    ) async throws -> MeasurementAccuracyType {
        localSettings.temperatureAccuracy = temperatureAccuracy
        return try await RuuviServiceError.perform {
            try await self.cloud.set(temperatureAccuracy: temperatureAccuracy)
        }
    }

    @discardableResult
    public func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit {
        localSettings.humidityUnit = humidityUnit
        return try await RuuviServiceError.perform {
            try await self.cloud.set(humidityUnit: humidityUnit)
        }
    }

    @discardableResult
    public func set(
        humidityAccuracy: MeasurementAccuracyType
    ) async throws -> MeasurementAccuracyType {
        localSettings.humidityAccuracy = humidityAccuracy
        return try await RuuviServiceError.perform {
            try await self.cloud.set(humidityAccuracy: humidityAccuracy)
        }
    }

    @discardableResult
    public func set(pressureUnit: UnitPressure) async throws -> UnitPressure {
        localSettings.pressureUnit = pressureUnit
        return try await RuuviServiceError.perform {
            try await self.cloud.set(pressureUnit: pressureUnit)
        }
    }

    @discardableResult
    public func set(
        pressureAccuracy: MeasurementAccuracyType
    ) async throws -> MeasurementAccuracyType {
        localSettings.pressureAccuracy = pressureAccuracy
        return try await RuuviServiceError.perform {
            try await self.cloud.set(pressureAccuracy: pressureAccuracy)
        }
    }

    @discardableResult
    public func set(showAllData: Bool) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(showAllData: showAllData)
        }
    }

    @discardableResult
    public func set(drawDots: Bool) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(drawDots: drawDots)
        }
    }

    @discardableResult
    public func set(chartDuration: Int) async throws -> Int {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(chartDuration: chartDuration)
        }
    }

    @discardableResult
    public func set(showMinMaxAvg: Bool) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(showMinMaxAvg: showMinMaxAvg)
        }
    }

    @discardableResult
    public func set(cloudMode: Bool) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(cloudMode: cloudMode)
        }
    }

    @discardableResult
    public func set(dashboard: Bool) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(dashboard: dashboard)
        }
    }

    @discardableResult
    public func set(dashboardType: DashboardType) async throws -> DashboardType {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(dashboardType: dashboardType)
        }
    }

    @discardableResult
    public func set(
        dashboardTapActionType: DashboardTapActionType
    ) async throws -> DashboardTapActionType {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(dashboardTapActionType: dashboardTapActionType)
        }
    }

    @discardableResult
    public func set(disableEmailAlert: Bool) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(disableEmailAlert: disableEmailAlert)
        }
    }

    @discardableResult
    public func set(disablePushAlert: Bool) async throws -> Bool {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(disablePushAlert: disablePushAlert)
        }
    }

    @discardableResult
    public func set(marketingPreference: Bool) async throws -> Bool {
        localSettings.marketingPreference = marketingPreference
        return try await RuuviServiceError.perform {
            try await self.cloud.set(marketingPreference: marketingPreference)
        }
    }

    @discardableResult
    public func set(profileLanguageCode: String) async throws -> String {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(profileLanguageCode: profileLanguageCode)
        }
    }

    @discardableResult
    public func set(dashboardSensorOrder: [String]) async throws -> [String] {
        return try await RuuviServiceError.perform {
            try await self.cloud.set(dashboardSensorOrder: dashboardSensorOrder)
        }
    }
}
