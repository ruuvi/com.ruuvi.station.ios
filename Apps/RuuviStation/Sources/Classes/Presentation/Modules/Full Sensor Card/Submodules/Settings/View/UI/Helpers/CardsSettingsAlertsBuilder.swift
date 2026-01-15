// swiftlint:disable file_length

import Foundation
import Humidity
import RuuviLocalization
import RuuviOntology
import RuuviService

struct CardsSettingsAlertsBuilder {
    // Alert types that are not related to anyt measurements and not
    // eligible for visibility settings.
    private static let auxiliaryAlertTypes: [AlertType] = [
        .connection,
        .cloudConnection(unseenDuration: 0),
    ]

    private struct Constants {
        static let configFormat: String = "%.0f"
        static let latestMeasurementRoundTo: Int = 2
    }

    static func makeSections(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> [CardsSettingsAlertSectionModel] {
        orderedAlertTypes(
            for: snapshot,
            measurementService: measurementService
        ).compactMap { prototype in
            makeSection(
                for: prototype,
                snapshot: snapshot,
                measurementService: measurementService
            )
        }
    }

    private static func orderedAlertTypes(
        for snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> [AlertType] {
        var ordered: [AlertType] = []

        let profile = RuuviTagDataService.measurementDisplayProfile(for: snapshot)
        let alertVariants = profile.entries(for: .alert).map(\.variant)

        let visibilityOrder = snapshot.displayData.measurementVisibility?.visibleVariants
            ?? profile.orderedVisibleVariants(for: .indicator)

        // Honor the visible order for measurement-based alerts (e.g., humidity variants).
        for variant in visibilityOrder {
            guard let alertType = variant.toAlertType() else { continue }
            if !ordered.contains(where: { $0.rawValue == alertType.rawValue }) {
                ordered.append(alertType)
            }
        }

        // Append any remaining alert-capable variants from the alert profile.
        for variant in alertVariants {
            guard let alertType = variant.toAlertType() else { continue }
            if !ordered.contains(where: { $0.rawValue == alertType.rawValue }) {
                ordered.append(alertType)
            }
        }

        for fallback in auxiliaryAlertTypes {
            if let measurementType = fallback.toMeasurementType() {
                let supported = alertVariants.contains {
                    $0.type.isSameCase(as: measurementType)
                }
                if !supported {
                    continue
                }
            }

            if !ordered.contains(where: { $0.rawValue == fallback.rawValue }) {
                ordered.append(fallback)
            }
        }

        return ordered
    }
}

// MARK: - Builders
private extension CardsSettingsAlertsBuilder {
    static func makeSection(
        for type: AlertType,
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> CardsSettingsAlertSectionModel? {
        guard shouldDisplay(type: type, snapshot: snapshot) else {
            return nil
        }

        let config = snapshot.getAlertConfig(for: type) ??
            RuuviTagCardSnapshotAlertConfig.defaultConfig(for: type)
        let hasMeasurement = hasMeasurementData(for: type, snapshot: snapshot)

        let headerState = CardsSettingsAlertSectionModel.HeaderState(
            isOn: config.isActive,
            mutedTill: config.mutedTill,
            alertState: config.isFiring ? .firing : (config.isActive ? .registered : .empty),
            showStatusLabel: !snapshot.capabilities.hideSwitchStatusLabel
        )

        let title = alertTitle(for: type, measurementService: measurementService)

        let (configuration, isInteractionEnabled) = configurationForAlert(
            type: type,
            snapshot: snapshot,
            config: config,
            measurementService: measurementService,
            hasMeasurement: hasMeasurement
        )

        return CardsSettingsAlertSectionModel(
            id: "alert.\(type.rawValue)",
            title: title,
            alertType: type,
            headerState: headerState,
            configuration: configuration,
            isInteractionEnabled: isInteractionEnabled
        )
    }
}

// MARK: - Configuration factories
private extension CardsSettingsAlertsBuilder {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func configurationForAlert(
        type: AlertType,
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        measurementService: RuuviServiceMeasurement?,
        hasMeasurement: Bool
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        switch type {
        case .temperature:
            return adjustedInteraction(
                temperatureConfiguration(
                    snapshot: snapshot,
                    config: config,
                    measurementService: measurementService,
                    hasMeasurement: hasMeasurement
                ),
                snapshot: snapshot
            )
        case .relativeHumidity:
            return adjustedInteraction(
                humidityConfiguration(
                    snapshot: snapshot,
                    config: config,
                    measurementService: measurementService,
                    hasMeasurement: hasMeasurement
                ),
                snapshot: snapshot
            )
        case .humidity:
            return adjustedInteraction(
                absoluteHumidityConfiguration(
                    snapshot: snapshot,
                    config: config,
                    measurementService: measurementService,
                    hasMeasurement: hasMeasurement
                ),
                snapshot: snapshot
            )
        case .dewPoint:
            return adjustedInteraction(
                dewPointConfiguration(
                    snapshot: snapshot,
                    config: config,
                    measurementService: measurementService,
                    hasMeasurement: hasMeasurement
                ),
                snapshot: snapshot
            )
        case .pressure:
            return adjustedInteraction(
                pressureConfiguration(
                    snapshot: snapshot,
                    config: config,
                    measurementService: measurementService,
                    hasMeasurement: hasMeasurement
                ),
                snapshot: snapshot
            )
        case .signal:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.Signal.lowerBound...RuuviAlertConstants.Signal.upperBound,
                    unit: RuuviLocalization.dBm,
                    format: Constants.configFormat,
                    latestMeasurement: latestSignal(snapshot: snapshot),
                    notice: RuuviLocalization.rssiAlertDescription
                ),
                snapshot: snapshot
            )
        case .batteryVoltage:
            return adjustedInteraction(
                batteryVoltageConfiguration(
                    snapshot: snapshot,
                    config: config,
                    measurementService: measurementService,
                    hasMeasurement: hasMeasurement
                ),
                snapshot: snapshot
            )
        case .aqi:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.AQI.lowerBound...RuuviAlertConstants.AQI.upperBound,
                    unit: "",
                    format: Constants.configFormat,
                    latestMeasurement: latestAQI(snapshot: snapshot, measurementService: measurementService)
                ),
                snapshot: snapshot
            )
        case .carbonDioxide:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.CarbonDioxide.lowerBound...RuuviAlertConstants.CarbonDioxide.upperBound,
                    unit: RuuviLocalization.unitCo2,
                    format: Constants.configFormat,
                    latestMeasurement: latestCO2(
                        snapshot: snapshot,
                        measurementService: measurementService
                    )
                ),
                snapshot: snapshot
            )
        case .pMatter1:
            return adjustedInteraction(
                particulateConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    unit: RuuviLocalization.unitPm10,
                    latest: snapshot.latestRawRecord?.pm1,
                    measurementService: measurementService
                ),
                snapshot: snapshot
            )
        case .pMatter25:
            return adjustedInteraction(
                particulateConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    unit: RuuviLocalization.unitPm25,
                    latest: snapshot.latestRawRecord?.pm25,
                    measurementService: measurementService
                ),
                snapshot: snapshot
            )
        case .pMatter4:
            return adjustedInteraction(
                particulateConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    unit: RuuviLocalization.unitPm40,
                    latest: snapshot.latestRawRecord?.pm4,
                    measurementService: measurementService
                ),
                snapshot: snapshot
            )
        case .pMatter10:
            return adjustedInteraction(
                particulateConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    unit: RuuviLocalization.unitPm100,
                    latest: snapshot.latestRawRecord?.pm10,
                    measurementService: measurementService
                ),
                snapshot: snapshot
            )
        case .voc:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.VOC.lowerBound...RuuviAlertConstants.VOC.upperBound,
                    unit: "",
                    format: Constants.configFormat,
                    latestMeasurement: latestVOC(
                        snapshot: snapshot,
                        measurementService: measurementService
                    )
                ),
                snapshot: snapshot
            )
        case .nox:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.NOX.lowerBound...RuuviAlertConstants.NOX.upperBound,
                    unit: "",
                    format: Constants.configFormat,
                    latestMeasurement: latestNOX(
                        snapshot: snapshot,
                        measurementService: measurementService
                    )
                ),
                snapshot: snapshot
            )
        case .soundInstant:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.Sound.lowerBound...RuuviAlertConstants.Sound.upperBound,
                    unit: RuuviLocalization.dBm,
                    format: Constants.configFormat,
                    latestMeasurement: latestSound(
                        snapshot: snapshot,
                        measurementService: measurementService
                    )
                ),
                snapshot: snapshot
            )
        case .soundPeak:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.Sound.lowerBound...RuuviAlertConstants.Sound.upperBound,
                    unit: RuuviLocalization.dBm,
                    format: Constants.configFormat,
                    latestMeasurement: peakSound(
                        snapshot: snapshot,
                        measurementService: measurementService
                    )
                ),
                snapshot: snapshot
            )
        case .soundAverage:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.Sound.lowerBound...RuuviAlertConstants.Sound.upperBound,
                    unit: RuuviLocalization.dBm,
                    format: Constants.configFormat,
                    latestMeasurement: avgSound(
                        snapshot: snapshot,
                        measurementService: measurementService
                    )
                ),
                snapshot: snapshot
            )
        case .luminosity:
            return adjustedInteraction(
                simpleRangeConfiguration(
                    snapshot: snapshot,
                    config: config,
                    hasMeasurement: hasMeasurement,
                    range: RuuviAlertConstants.Luminosity.lowerBound...RuuviAlertConstants.Luminosity.upperBound,
                    unit: RuuviLocalization.unitLuminosity,
                    format: Constants.configFormat,
                    latestMeasurement: latestLuminosity(
                        snapshot: snapshot,
                        measurementService: measurementService
                    )
                ),
                snapshot: snapshot
            )
        case .movement:
            return adjustedInteraction(
                movementConfiguration(config: config),
                snapshot: snapshot
            )
        case .connection:
            return adjustedInteraction(
                connectionConfiguration(config: config),
                snapshot: snapshot
            )
        case .cloudConnection:
            return adjustedInteraction(
                cloudConnectionConfiguration(config: config),
                snapshot: snapshot
            )
        }
    }
}

// MARK: - Individual configurations
private extension CardsSettingsAlertsBuilder {
    static func temperatureConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        measurementService: RuuviServiceMeasurement?,
        hasMeasurement: Bool
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let temperatureUnit = preferredTemperatureUnit(measurementService: measurementService)
        let rangeValues = temperatureUnit.alertRange
        let sliderRange = ClosedRange(uncheckedBounds: (rangeValues.lowerBound, rangeValues.upperBound))

        let lower = config.lowerBound.map {
            Temperature(value: $0, unit: .celsius).converted(
                to: temperatureUnit.unitTemperature
            ).value
        } ?? sliderRange.lowerBound

        let upper = config.upperBound.map {
            Temperature(value: $0, unit: .celsius).converted(
                to: temperatureUnit.unitTemperature
            ).value
        } ?? sliderRange.upperBound

        let selected = clamp(
            range: sliderRange,
            proposal: normalizedProposalRange(range: sliderRange, lower: lower, upper: upper)
        )

        let slider = CardsSettingsAlertSliderConfiguration(
            range: sliderRange,
            selectedRange: selected,
            unit: temperatureUnit.symbol,
            format: Constants.configFormat,
            step: 1,
            minDistance: 1
        )

        let latest = latestTemperature(
            snapshot: snapshot,
            measurementService: measurementService
        )

        return (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                noticeText: nil,
                customDescriptionText: config.description,
                limitDescription: .sliderLocalized,
                showsLimitEditIcon: true,
                sliderConfiguration: slider,
                additionalInfo: nil,
                latestMeasurement: latest
            ),
            hasMeasurement
        )
    }

    static func humidityConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        measurementService: RuuviServiceMeasurement?,
        hasMeasurement: Bool
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let sliderRange: ClosedRange<Double> =
        RuuviAlertConstants.RelativeHumidity.lowerBound...RuuviAlertConstants.RelativeHumidity.upperBound
        let lower = config.lowerBound ?? sliderRange.lowerBound
        let upper = config.upperBound ?? sliderRange.upperBound
        let selected = clamp(
            range: sliderRange,
            proposal: normalizedProposalRange(range: sliderRange, lower: lower, upper: upper)
        )

        let slider = CardsSettingsAlertSliderConfiguration(
            range: sliderRange,
            selectedRange: selected,
            unit: RuuviLocalization.humidityRelativeUnit,
            format: Constants.configFormat,
            step: 1,
            minDistance: 1
        )

        let latest = latestHumidity(
            snapshot: snapshot,
            measurementService: measurementService
        )

        return (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                noticeText: nil,
                customDescriptionText: config.description,
                limitDescription: .sliderLocalized,
                showsLimitEditIcon: true,
                sliderConfiguration: slider,
                additionalInfo: nil,
                latestMeasurement: latest
            ),
            hasMeasurement
        )
    }

    static func absoluteHumidityConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        measurementService: RuuviServiceMeasurement?,
        hasMeasurement: Bool
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let sliderRange: ClosedRange<Double> =
        RuuviAlertConstants.AbsoluteHumidity.lowerBound...RuuviAlertConstants.AbsoluteHumidity.upperBound
        let lower = config.lowerBound ?? sliderRange.lowerBound
        let upper = config.upperBound ?? sliderRange.upperBound
        let selected = clamp(
            range: sliderRange,
            proposal: normalizedProposalRange(range: sliderRange, lower: lower, upper: upper)
        )

        let slider = CardsSettingsAlertSliderConfiguration(
            range: sliderRange,
            selectedRange: selected,
            unit: HumidityUnit.gm3.symbol,
            format: Constants.configFormat,
            step: 1,
            minDistance: 1
        )

        let latest = latestAbsoluteHumidity(
            snapshot: snapshot,
            measurementService: measurementService
        )

        return (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                noticeText: nil,
                customDescriptionText: config.description,
                limitDescription: .sliderLocalized,
                showsLimitEditIcon: true,
                sliderConfiguration: slider,
                additionalInfo: nil,
                latestMeasurement: latest
            ),
            hasMeasurement
        )
    }

    static func dewPointConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        measurementService: RuuviServiceMeasurement?,
        hasMeasurement: Bool
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let temperatureUnit = preferredTemperatureUnit(measurementService: measurementService)
        let rangeLower = Temperature(value: RuuviAlertConstants.DewPoint.lowerBound, unit: .celsius)
            .converted(to: temperatureUnit.unitTemperature)
            .value
        let rangeUpper = Temperature(value: RuuviAlertConstants.DewPoint.upperBound, unit: .celsius)
            .converted(to: temperatureUnit.unitTemperature)
            .value
        let sliderRange = ClosedRange(uncheckedBounds: (rangeLower, rangeUpper))

        let lower = config.lowerBound.map {
            Temperature(value: $0, unit: .celsius)
                .converted(to: temperatureUnit.unitTemperature)
                .value
        } ?? sliderRange.lowerBound

        let upper = config.upperBound.map {
            Temperature(value: $0, unit: .celsius)
                .converted(to: temperatureUnit.unitTemperature)
                .value
        } ?? sliderRange.upperBound

        let selected = clamp(
            range: sliderRange,
            proposal: normalizedProposalRange(range: sliderRange, lower: lower, upper: upper)
        )

        let slider = CardsSettingsAlertSliderConfiguration(
            range: sliderRange,
            selectedRange: selected,
            unit: temperatureUnit.symbol,
            format: Constants.configFormat,
            step: 1,
            minDistance: 1
        )

        let latest = latestDewPoint(
            snapshot: snapshot,
            measurementService: measurementService
        )

        return (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                noticeText: nil,
                customDescriptionText: config.description,
                limitDescription: .sliderLocalized,
                showsLimitEditIcon: true,
                sliderConfiguration: slider,
                additionalInfo: nil,
                latestMeasurement: latest
            ),
            hasMeasurement
        )
    }

    static func pressureConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        measurementService: RuuviServiceMeasurement?,
        hasMeasurement: Bool
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let pressureUnit = measurementService?.units.pressureUnit ?? .hectopascals
        let baseRange = pressureUnit.alertRange
        let sliderRange = ClosedRange(uncheckedBounds: (baseRange.lowerBound, baseRange.upperBound))

        let lower = config.lowerBound.map {
            convertPressureValue($0, to: pressureUnit)
        } ?? sliderRange.lowerBound

        let upper = config.upperBound.map {
            convertPressureValue($0, to: pressureUnit)
        } ?? sliderRange.upperBound

        let selected = clamp(
            range: sliderRange,
            proposal: normalizedProposalRange(range: sliderRange, lower: lower, upper: upper)
        )

        let slider = CardsSettingsAlertSliderConfiguration(
            range: sliderRange,
            selectedRange: selected,
            unit: pressureUnit.ruuviSymbol,
            format: Constants.configFormat,
            step: 1,
            minDistance: 1
        )

        let latest = latestPressure(
            snapshot: snapshot,
            measurementService: measurementService
        )

        return (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                customDescriptionText: config.description,
                limitDescription: .sliderLocalized,
                showsLimitEditIcon: true,
                sliderConfiguration: slider,
                latestMeasurement: latest
            ),
            hasMeasurement
        )
    }

    static func batteryVoltageConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        measurementService: RuuviServiceMeasurement?,
        hasMeasurement: Bool
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let sliderRange: ClosedRange<Double> =
        RuuviAlertConstants.BatteryVoltage.lowerBound...RuuviAlertConstants.BatteryVoltage.upperBound
        let lower = config.lowerBound ?? sliderRange.lowerBound
        let upper = config.upperBound ?? sliderRange.upperBound
        let selected = clamp(
            range: sliderRange,
            proposal: normalizedProposalRange(range: sliderRange, lower: lower, upper: upper)
        )

        let slider = CardsSettingsAlertSliderConfiguration(
            range: sliderRange,
            selectedRange: selected,
            unit: RuuviLocalization.v,
            format: "%.2f",
            step: 0.1,
            minDistance: 0.1
        )

        let latest = latestBatteryVoltage(
            snapshot: snapshot,
            measurementService: measurementService
        )

        return (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                noticeText: nil,
                customDescriptionText: config.description,
                limitDescription: .sliderLocalized,
                showsLimitEditIcon: true,
                sliderConfiguration: slider,
                additionalInfo: nil,
                latestMeasurement: latest
            ),
            hasMeasurement
        )
    }

    // swiftlint:disable:next function_parameter_count
    static func simpleRangeConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        hasMeasurement: Bool,
        range: ClosedRange<Double>,
        unit: String,
        format: String,
        latestMeasurement: String?,
        notice: String? = nil
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let lower = config.lowerBound ?? range.lowerBound
        let upper = config.upperBound ?? range.upperBound
        let selected = clamp(
            range: range,
            proposal: normalizedProposalRange(range: range, lower: lower, upper: upper)
        )

        let slider = CardsSettingsAlertSliderConfiguration(
            range: range,
            selectedRange: selected,
            unit: unit,
            format: format,
            step: 1,
            minDistance: 1
        )

        let configuration = CardsSettingsAlertUIConfiguration(
            isEnabled: config.isActive,
            noticeText: notice,
            customDescriptionText: config.description,
            limitDescription: .sliderLocalized,
            showsLimitEditIcon: true,
            sliderConfiguration: slider,
            additionalInfo: nil,
            latestMeasurement: latestMeasurement
        )

        return (configuration, hasMeasurement)
    }

    static func adjustedInteraction(
        _ result: (CardsSettingsAlertUIConfiguration, Bool),
        snapshot: RuuviTagCardSnapshot
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let (configuration, baseEnabled) = result
        let finalEnabled = baseEnabled &&
            snapshot.capabilities.isAlertsEnabled &&
            snapshot.capabilities.isPushNotificationsAvailable
        return (configuration, finalEnabled)
    }

    // swiftlint:disable:next function_parameter_count
    static func particulateConfiguration(
        snapshot: RuuviTagCardSnapshot,
        config: RuuviTagCardSnapshotAlertConfig,
        hasMeasurement: Bool,
        unit: String,
        latest: Double?,
        measurementService: RuuviServiceMeasurement?
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let range = RuuviAlertConstants.ParticulateMatter.lowerBound...RuuviAlertConstants.ParticulateMatter.upperBound

        var latestMeasurement = RuuviLocalization.na
        if let latest, let measurementService {
            latestMeasurement = "\(measurementService.pm10String(for: latest)) \(unit)"
        }

        return simpleRangeConfiguration(
            snapshot: snapshot,
            config: config,
            hasMeasurement: hasMeasurement,
            range: range,
            unit: unit,
            format: Constants.configFormat,
            latestMeasurement: latestMeasurement
        )
    }

    static func movementConfiguration(
        config: RuuviTagCardSnapshotAlertConfig
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                noticeText: RuuviLocalization.TagSettings.Alerts.Movement.description,
                customDescriptionText: config.description,
                showsLimitEditIcon: false
            ),
            true
        )
    }

    static func connectionConfiguration(
        config: RuuviTagCardSnapshotAlertConfig
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                customDescriptionText: config.description,
                showsLimitEditIcon: false,
                additionalInfo: RuuviLocalization.TagSettings.Alerts.Connection.description
            ),
            true
        )
    }

    static func cloudConnectionConfiguration(
        config: RuuviTagCardSnapshotAlertConfig
    ) -> (CardsSettingsAlertUIConfiguration, Bool) {
        let delayMinutes = Int(
            (
                config.unseenDuration ?? Double(RuuviAlertConstants.CloudConnection.defaultUnseenDuration)
            ) / 60
        )
        let description = RuuviLocalization.alertCloudConnectionDescription(delayMinutes)

        return (
            CardsSettingsAlertUIConfiguration(
                isEnabled: config.isActive,
                customDescriptionText: config.description,
                limitDescription: .staticText(description),
                showsLimitEditIcon: true
            ),
            true
        )
    }
}

// MARK: - Helpers
private extension CardsSettingsAlertsBuilder {

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func alertTitle(
        for alertType: AlertType,
        measurementService: RuuviServiceMeasurement?
    ) -> String {
        let units = measurementService?.units
        switch alertType {
        case .temperature:
            let unit = units?.temperatureUnit.symbol ?? TemperatureUnit.celsius.symbol
            return AlertType.temperature(lower: 0, upper: 0).title(with: unit)
        case .dewPoint:
            let unit = units?.temperatureUnit.symbol ?? TemperatureUnit.celsius.symbol
            return AlertType.dewPoint(lower: 0, upper: 0).title(with: unit)
        case .pressure:
            let unit = units?.pressureUnit.ruuviSymbol ?? UnitPressure.hectopascals.ruuviSymbol
            return AlertType.pressure(lower: 0, upper: 0).title(with: unit)
        case .carbonDioxide:
            return AlertType.carbonDioxide(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitCo2)
        case .pMatter1:
            return AlertType.pMatter1(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitPm10)
        case .pMatter4:
            return AlertType.pMatter4(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitPm10)
        case .pMatter25:
            return AlertType.pMatter25(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitPm25)
        case .pMatter10:
            return AlertType.pMatter10(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitPm10)
        case .voc:
            return AlertType.voc(lower: 0, upper: 0).title()
        case .nox:
            return AlertType.nox(lower: 0, upper: 0).title()
        case .luminosity:
            return AlertType.luminosity(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitLuminosity)
        case .soundInstant:
            return AlertType
                .soundInstant(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitSound)
        case .soundPeak:
            return AlertType
                .soundPeak(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitSound)
        case .soundAverage:
            return AlertType
                .soundAverage(lower: 0, upper: 0)
                .title(with: RuuviLocalization.unitSound)
        case .batteryVoltage:
            return AlertType
                .batteryVoltage(lower: 0, upper: 0)
                .title(with: RuuviLocalization.v)
        default:
            return alertType.title()
        }
    }

    static func preferredTemperatureUnit(
        measurementService: RuuviServiceMeasurement?
    ) -> TemperatureUnit {
        guard let unit = measurementService?.units.temperatureUnit else {
            return .celsius
        }

        switch unit {
        case .fahrenheit:
            return .fahrenheit
        case .kelvin:
            return .kelvin
        default:
            return .celsius
        }
    }

    static func shouldDisplay(
        type: AlertType,
        snapshot: RuuviTagCardSnapshot
    ) -> Bool {
        switch type {
        case .connection:
            return snapshot.capabilities.showKeepConnection &&
                snapshot.connectionData.isConnectable
        case .cloudConnection:
            return snapshot.capabilities.isCloudConnectionAlertsAvailable
        default:
            return hasMeasurementData(for: type, snapshot: snapshot)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func hasMeasurementData(
        for type: AlertType,
        snapshot: RuuviTagCardSnapshot
    ) -> Bool {
        guard let record = snapshot.latestRawRecord else { return false }
        switch type {
        case .aqi:
            return record.co2 != nil && record.pm25 != nil
        case .carbonDioxide:
            return record.co2 != nil
        case .pMatter1:
            return record.pm1 != nil
        case .pMatter25:
            return record.pm25 != nil
        case .pMatter4:
            return record.pm4 != nil
        case .pMatter10:
            return record.pm10 != nil
        case .voc:
            return record.voc != nil
        case .nox:
            return record.nox != nil
        case .temperature:
            return record.temperature != nil
        case .relativeHumidity:
            return record.humidity != nil
        case .humidity:
            return record.humidity != nil && record.temperature != nil
        case .dewPoint:
            return record.humidity != nil && record.temperature != nil
        case .pressure:
            return record.pressure != nil
        case .luminosity:
            return record.luminance != nil
        case .movement:
            return record.movementCounter != nil
        case .soundInstant:
            return record.dbaInstant != nil
        case .soundPeak:
            return record.dbaPeak != nil
        case .soundAverage:
            return record.dbaAvg != nil
        case .signal:
            return record.rssi != nil
        case .batteryVoltage:
            return record.voltage != nil
        default:
            return false
        }
    }

    static func clamp(
        range: ClosedRange<Double>,
        proposal: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        let lower = max(range.lowerBound, min(range.upperBound, proposal.lowerBound))
        let upper = max(lower, min(range.upperBound, proposal.upperBound))
        return lower...upper
    }

    static func normalizedProposalRange(
        range: ClosedRange<Double>,
        lower: Double,
        upper: Double
    ) -> ClosedRange<Double> {
        let safeLower = lower.isFinite ? lower : range.lowerBound
        let safeUpper = upper.isFinite ? upper : range.upperBound
        let normalizedLower = min(safeLower, safeUpper)
        let normalizedUpper = max(safeLower, safeUpper)
        return normalizedLower...normalizedUpper
    }

    static func convertPressureValue(
        _ value: Double,
        to unit: UnitPressure
    ) -> Double {
        Pressure(value, unit: .hectopascals)?
            .converted(to: unit)
            .value ?? value
    }

    static func latestTemperature(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let measurementService,
              let temperature = snapshot.latestRawRecord?.temperature,
              temperature.value.isFinite else {
            return nil
        }
        return measurementService.string(for: temperature, allowSettings: true)
    }

    static func latestHumidity(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let measurementService,
              let record = snapshot.latestRawRecord,
              let humidity = record.humidity,
              humidity.value.isFinite else {
            return nil
        }
        let temperature = record.temperature
        let safeTemperature = temperature?.value.isFinite == true ? temperature : nil
        return measurementService.string(
            for: humidity,
            temperature: safeTemperature,
            allowSettings: true,
            unit: .percent
        )
    }

    static func latestAbsoluteHumidity(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let measurementService,
              let record = snapshot.latestRawRecord,
              let humidity = record.humidity,
              let temperature = record.temperature,
              humidity.value.isFinite,
              temperature.value.isFinite else {
            return nil
        }
        return measurementService.string(
            for: humidity,
            temperature: temperature,
            allowSettings: true,
            unit: .gm3
        )
    }

    static func latestDewPoint(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let measurementService,
              let record = snapshot.latestRawRecord,
              let humidity = record.humidity,
              let temperature = record.temperature,
              humidity.value.isFinite,
              temperature.value.isFinite else {
            return nil
        }
        return measurementService.string(
            for: humidity,
            temperature: temperature,
            allowSettings: true,
            unit: .dew
        )
    }

    static func latestPressure(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let measurementService,
              let pressure = snapshot.latestRawRecord?.pressure else {
            return nil
        }
        return measurementService.string(for: pressure, allowSettings: true)
    }

    static func latestBatteryVoltage(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let measurementService,
              let voltage = snapshot.latestRawRecord?.voltage else {
            return nil
        }
        return measurementService.string(for: voltage)
    }

    static func latestSignal(snapshot: RuuviTagCardSnapshot) -> String? {
        let value = snapshot.latestRawRecord?.rssi ??
            snapshot.displayData.latestRSSI
        guard let value else { return nil }
        return "\(value) \(RuuviLocalization.dBm)"
    }

    static func latestAQI(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let measurementService,
              let record = snapshot.latestRawRecord else {
            return nil
        }

        let (aqi, _, _) = measurementService.aqi(
            for: record.co2,
            pm25: record.pm25
        )
        return "\(aqi)"
    }

    static func latestCO2(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let value = snapshot.latestRawRecord?.co2,
                let measurementService else { return nil }
        return "\(measurementService.co2String(for: value)) \(RuuviLocalization.unitCo2)"
    }

    static func latestVOC(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let value = snapshot.latestRawRecord?.voc,
                let measurementService else { return nil }
        return measurementService.vocString(for: value)
    }

    static func latestNOX(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let value = snapshot.latestRawRecord?.nox,
                let measurementService else { return nil }
        return measurementService.vocString(for: value)
    }

    static func latestSound(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let value = snapshot.latestRawRecord?.dbaInstant,
                let measurementService else { return nil }
        return "\(measurementService.soundString(for: value)) \(RuuviLocalization.dBm)"
    }

    static func peakSound(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let value = snapshot.latestRawRecord?.dbaPeak,
                let measurementService else { return nil }
        return "\(measurementService.soundString(for: value)) \(RuuviLocalization.dBm)"
    }

    static func avgSound(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let value = snapshot.latestRawRecord?.dbaAvg,
                let measurementService else { return nil }
        return "\(measurementService.soundString(for: value)) \(RuuviLocalization.dBm)"
    }

    static func latestLuminosity(
        snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> String? {
        guard let value = snapshot.latestRawRecord?.luminance,
                let measurementService else { return nil }
        return "\(measurementService.luminosityString(for: value)) \(RuuviLocalization.unitLuminosity)"
    }
}

// MARK: - Defaults
private extension RuuviTagCardSnapshotAlertConfig {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func defaultConfig(for alertType: AlertType) -> RuuviTagCardSnapshotAlertConfig {
        let measurementType = alertType.toMeasurementType()

        switch alertType {
        case .temperature:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .temperature(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.Temperature.lowerBound,
                upperBound: RuuviAlertConstants.Temperature.upperBound
            )
        case .relativeHumidity:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .relativeHumidity(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.RelativeHumidity.lowerBound,
                upperBound: RuuviAlertConstants.RelativeHumidity.upperBound
            )
        case .humidity:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.AbsoluteHumidity.lowerBound,
                upperBound: RuuviAlertConstants.AbsoluteHumidity.upperBound
            )
        case .dewPoint:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .dewPoint(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.DewPoint.lowerBound,
                upperBound: RuuviAlertConstants.DewPoint.upperBound
            )
        case .pressure:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .pressure(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.Pressure.lowerBound,
                upperBound: RuuviAlertConstants.Pressure.upperBound
            )
        case .signal:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .signal(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.Signal.lowerBound,
                upperBound: RuuviAlertConstants.Signal.upperBound
            )
        case .aqi:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .aqi(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.AQI.lowerBound,
                upperBound: RuuviAlertConstants.AQI.upperBound
            )
        case .carbonDioxide:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .carbonDioxide(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.CarbonDioxide.lowerBound,
                upperBound: RuuviAlertConstants.CarbonDioxide.upperBound
            )
        case .pMatter1, .pMatter25, .pMatter4, .pMatter10:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: alertType,
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.ParticulateMatter.lowerBound,
                upperBound: RuuviAlertConstants.ParticulateMatter.upperBound
            )
        case .voc:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .voc(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.VOC.lowerBound,
                upperBound: RuuviAlertConstants.VOC.upperBound
            )
        case .nox:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .nox(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.NOX.lowerBound,
                upperBound: RuuviAlertConstants.NOX.upperBound
            )
        case .soundInstant:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .soundInstant(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.Sound.lowerBound,
                upperBound: RuuviAlertConstants.Sound.upperBound
            )
        case .soundPeak:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .soundPeak(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.Sound.lowerBound,
                upperBound: RuuviAlertConstants.Sound.upperBound
            )
        case .soundAverage:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .soundAverage(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.Sound.lowerBound,
                upperBound: RuuviAlertConstants.Sound.upperBound
            )
        case .luminosity:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .luminosity(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.Luminosity.lowerBound,
                upperBound: RuuviAlertConstants.Luminosity.upperBound
            )
        case .batteryVoltage:
            return RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: .batteryVoltage(lower: 0, upper: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                lowerBound: RuuviAlertConstants.BatteryVoltage.lowerBound,
                upperBound: RuuviAlertConstants.BatteryVoltage.upperBound
            )
        case .movement:
            return RuuviTagCardSnapshotAlertConfig(
                alertType: .movement(last: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil
            )
        case .connection:
            return RuuviTagCardSnapshotAlertConfig(
                alertType: .connection,
                isActive: false,
                isFiring: false,
                mutedTill: nil
            )
        case .cloudConnection:
            return RuuviTagCardSnapshotAlertConfig(
                alertType: .cloudConnection(unseenDuration: 0),
                isActive: false,
                isFiring: false,
                mutedTill: nil,
                unseenDuration: Double(RuuviAlertConstants.CloudConnection.defaultUnseenDuration)
            )
        }
    }
}

// swiftlint:enable file_length
