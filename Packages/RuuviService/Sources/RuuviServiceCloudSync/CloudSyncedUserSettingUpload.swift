#if SWIFT_PACKAGE
    import RuuviService
#endif
import Foundation
import RuuviCloud
import RuuviOntology

extension RuuviCloudApiSetting {
    @discardableResult
    @MainActor
    func upload(
        userSetting: RuuviUserSetting,
        using cloud: RuuviCloud
    ) async -> Bool {
        guard userSetting.key == key else {
            return false
        }
        return await upload(value: userSetting.value, using: cloud)
    }

    @discardableResult
    @MainActor
    func upload(
        value: String,
        using cloud: RuuviCloud
    ) async -> Bool {
        switch self {
        case .unitTemperature, .unitHumidity, .unitPressure:
            await uploadMeasurementUnitValue(value, using: cloud)
        case .accuracyTemperature, .accuracyHumidity, .accuracyHumidityRelative,
            .accuracyHumidityAbsolute, .accuracyHumidityDewPoint,
            .accuracyPressure, .accuracyPM, .accuracyAcceleration, .accuracyVoltage:
            await uploadMeasurementAccuracyValue(value, using: cloud)
        case .chartShowAllPoints, .chartDrawDots, .chartViewPeriod, .chartShowMinMaxAverage:
            await uploadChartValue(value, using: cloud)
        case .cloudModeEnabled, .dashboardEnabled, .dashboardType, .dashboardTapActionType:
            await uploadDashboardValue(value, using: cloud)
        case .emailAlertDisabled, .pushAlertDisabled, .marketingPreference,
            .profileLanguageCode, .dashboardSensorOrder:
            await uploadAccountValue(value, using: cloud)
        default:
            false
        }
    }

    @MainActor
    private func uploadMeasurementUnitValue(
        _ value: String,
        using cloud: RuuviCloud
    ) async -> Bool {
        switch self {
        case .unitTemperature:
            guard let value = value.ruuviCloudApiSettingUnitTemperature else { return false }
            _ = try? await cloud.set(temperatureUnit: value)
        case .unitHumidity:
            guard let value = value.ruuviCloudApiSettingUnitHumidity else { return false }
            _ = try? await cloud.set(humidityUnit: value)
        case .unitPressure:
            guard let value = value.ruuviCloudApiSettingUnitPressure else { return false }
            _ = try? await cloud.set(pressureUnit: value)
        default:
            preconditionFailure("Unexpected measurement unit setting")
        }
        return true
    }

    @MainActor
    private func uploadMeasurementAccuracyValue(
        _ value: String,
        using cloud: RuuviCloud
    ) async -> Bool {
        guard let value = value.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional else {
            return false
        }
        switch self {
        case .accuracyTemperature:
            _ = try? await cloud.set(temperatureAccuracy: value)
        case .accuracyHumidity:
            _ = try? await cloud.set(humidityAccuracy: value)
        case .accuracyHumidityRelative, .accuracyHumidityAbsolute, .accuracyHumidityDewPoint:
            _ = try? await cloud.set(userSetting: self, value: value.value.ruuviCloudApiSettingString)
        case .accuracyPressure:
            _ = try? await cloud.set(pressureAccuracy: value)
        case .accuracyPM, .accuracyAcceleration, .accuracyVoltage:
            _ = try? await cloud.set(userSetting: self, value: value.value.ruuviCloudApiSettingString)
        default:
            preconditionFailure("Unexpected measurement accuracy setting")
        }
        return true
    }

    @MainActor
    private func uploadChartValue(
        _ value: String,
        using cloud: RuuviCloud
    ) async -> Bool {
        switch self {
        case .chartShowAllPoints:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(showAllData: value)
        case .chartDrawDots:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(drawDots: value)
        case .chartViewPeriod:
            guard let value = value.ruuviCloudApiSettingChartViewPeriod else { return false }
            _ = try? await cloud.set(chartDuration: value)
        case .chartShowMinMaxAverage:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(showMinMaxAvg: value)
        default:
            preconditionFailure("Unexpected chart setting")
        }
        return true
    }

    @MainActor
    private func uploadDashboardValue(
        _ value: String,
        using cloud: RuuviCloud
    ) async -> Bool {
        switch self {
        case .cloudModeEnabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(cloudMode: value)
        case .dashboardEnabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(dashboard: value)
        case .dashboardType:
            guard let value = value.ruuviCloudApiSettingsDashboardTypeOptional else { return false }
            _ = try? await cloud.set(dashboardType: value)
        case .dashboardTapActionType:
            guard let value = value.ruuviCloudApiSettingsDashboardTapActionTypeOptional else { return false }
            _ = try? await cloud.set(dashboardTapActionType: value)
        default:
            preconditionFailure("Unexpected dashboard setting")
        }
        return true
    }

    @MainActor
    private func uploadAccountValue(
        _ value: String,
        using cloud: RuuviCloud
    ) async -> Bool {
        switch self {
        case .emailAlertDisabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(disableEmailAlert: value)
        case .pushAlertDisabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(disablePushAlert: value)
        case .marketingPreference:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            _ = try? await cloud.set(marketingPreference: value)
        case .profileLanguageCode:
            _ = try? await cloud.set(profileLanguageCode: value)
        case .dashboardSensorOrder:
            guard let value = RuuviCloudApiHelper.jsonArrayFromString(value) else { return false }
            _ = try? await cloud.set(dashboardSensorOrder: value)
        default:
            preconditionFailure("Unexpected account setting")
        }
        return true
    }

}
