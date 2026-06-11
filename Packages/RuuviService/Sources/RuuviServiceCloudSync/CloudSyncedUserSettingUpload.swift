import Foundation
import RuuviCloud
import RuuviOntology

extension RuuviCloudApiSetting {
    @discardableResult
    func upload(
        userSetting: RuuviUserSetting,
        using cloud: RuuviCloud
    ) -> Bool {
        guard userSetting.key == key else {
            return false
        }
        return upload(value: userSetting.value, using: cloud)
    }

    @discardableResult
    func upload(
        value: String,
        using cloud: RuuviCloud
    ) -> Bool {
        switch self {
        case .unitTemperature, .unitHumidity, .unitPressure:
            uploadMeasurementUnitValue(value, using: cloud)
        case .accuracyTemperature, .accuracyHumidity, .accuracyPressure:
            uploadMeasurementAccuracyValue(value, using: cloud)
        case .chartShowAllPoints, .chartDrawDots, .chartShowMinMaxAverage:
            uploadChartValue(value, using: cloud)
        case .cloudModeEnabled, .dashboardEnabled, .dashboardType, .dashboardTapActionType:
            uploadDashboardValue(value, using: cloud)
        case .emailAlertDisabled, .pushAlertDisabled, .marketingPreference,
             .profileLanguageCode, .dashboardSensorOrder:
            uploadAccountValue(value, using: cloud)
        default:
            false
        }
    }

    private func uploadMeasurementUnitValue(
        _ value: String,
        using cloud: RuuviCloud
    ) -> Bool {
        switch self {
        case .unitTemperature:
            guard let value = value.ruuviCloudApiSettingUnitTemperature else { return false }
            cloud.set(temperatureUnit: value).on()
        case .unitHumidity:
            guard let value = value.ruuviCloudApiSettingUnitHumidity else { return false }
            cloud.set(humidityUnit: value).on()
        case .unitPressure:
            guard let value = value.ruuviCloudApiSettingUnitPressure else { return false }
            cloud.set(pressureUnit: value).on()
        default:
            preconditionFailure("Unexpected measurement unit setting")
        }
        return true
    }

    private func uploadMeasurementAccuracyValue(
        _ value: String,
        using cloud: RuuviCloud
    ) -> Bool {
        guard let value = value.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional else {
            return false
        }
        switch self {
        case .accuracyTemperature:
            cloud.set(temperatureAccuracy: value).on()
        case .accuracyHumidity:
            cloud.set(humidityAccuracy: value).on()
        case .accuracyPressure:
            cloud.set(pressureAccuracy: value).on()
        default:
            preconditionFailure("Unexpected measurement accuracy setting")
        }
        return true
    }

    private func uploadChartValue(
        _ value: String,
        using cloud: RuuviCloud
    ) -> Bool {
        switch self {
        case .chartShowAllPoints:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(showAllData: value).on()
        case .chartDrawDots:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(drawDots: value).on()
        case .chartShowMinMaxAverage:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(showMinMaxAvg: value).on()
        default:
            preconditionFailure("Unexpected chart setting")
        }
        return true
    }

    private func uploadDashboardValue(
        _ value: String,
        using cloud: RuuviCloud
    ) -> Bool {
        switch self {
        case .cloudModeEnabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(cloudMode: value).on()
        case .dashboardEnabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(dashboard: value).on()
        case .dashboardType:
            guard let value = value.ruuviCloudApiSettingsDashboardTypeOptional else { return false }
            cloud.set(dashboardType: value).on()
        case .dashboardTapActionType:
            guard let value = value.ruuviCloudApiSettingsDashboardTapActionTypeOptional else { return false }
            cloud.set(dashboardTapActionType: value).on()
        default:
            preconditionFailure("Unexpected dashboard setting")
        }
        return true
    }

    private func uploadAccountValue(
        _ value: String,
        using cloud: RuuviCloud
    ) -> Bool {
        switch self {
        case .emailAlertDisabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(disableEmailAlert: value).on()
        case .pushAlertDisabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(disablePushAlert: value).on()
        case .marketingPreference:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            cloud.set(marketingPreference: value).on()
        case .profileLanguageCode:
            cloud.set(profileLanguageCode: value).on()
        case .dashboardSensorOrder:
            guard let value = RuuviCloudApiHelper.jsonArrayFromString(value) else { return false }
            cloud.set(dashboardSensorOrder: value).on()
        default:
            preconditionFailure("Unexpected account setting")
        }
        return true
    }

}
