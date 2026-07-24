import RuuviLocalization
import RuuviOntology

enum CardsAlertsDeliveryPromptDestination: Equatable {
    case sensorSettings
    case backgroundScanning
}

struct CardsAlertsDeliveryPrompt: Equatable {
    let message: String
    let buttonTitle: String
    let destination: CardsAlertsDeliveryPromptDestination

    static func make(
        for snapshot: RuuviTagCardSnapshot,
        isBackgroundScanningEnabled: Bool
    ) -> CardsAlertsDeliveryPrompt? {
        guard !snapshot.metadata.isCloud else { return nil }

        let format = RuuviDataFormat.dataFormat(
            from: snapshot.displayData.version.bound
        )
        let isRuuviAir = format == .e1 || format == .v6

        if isRuuviAir {
            guard !isBackgroundScanningEnabled else { return nil }
            return CardsAlertsDeliveryPrompt(
                message: RuuviLocalization.TagSettings.Alerts.DeliveryPrompt
                    .RuuviAirBackgroundScanningDisabled.text,
                buttonTitle: RuuviLocalization.TagSettings.Alerts.DeliveryPrompt
                    .GoToBackgroundScanning.button,
                destination: .backgroundScanning
            )
        }

        if !isBackgroundScanningEnabled {
            return CardsAlertsDeliveryPrompt(
                message: RuuviLocalization.TagSettings.Alerts.DeliveryPrompt
                    .RuuviTagBackgroundScanningDisabled.text,
                buttonTitle: RuuviLocalization.TagSettings.Alerts.DeliveryPrompt
                    .GoToSensorSettings.button,
                destination: .sensorSettings
            )
        }

        guard !snapshot.connectionData.keepConnection else { return nil }
        return CardsAlertsDeliveryPrompt(
            message: RuuviLocalization.TagSettings.Alerts.DeliveryPrompt
                .RuuviTagUnpaired.text,
            buttonTitle: RuuviLocalization.TagSettings.Alerts.DeliveryPrompt
                .GoToSensorSettings.button,
            destination: .sensorSettings
        )
    }
}
