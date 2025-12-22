import Combine
import UIKit
import RuuviOntology

@MainActor class CardsSettingsActions: ObservableObject {
    let didTapBackgroundChange = PassthroughSubject<Void, Never>()
    let didTapSnapshotName = PassthroughSubject<Void, Never>()
    let didTapOwnerRow = PassthroughSubject<Void, Never>()
    let didTapShareRow = PassthroughSubject<Void, Never>()
    let didTapVisibleMeasurementsRow = PassthroughSubject<Void, Never>()
    let didTapLedBrightnessRow = PassthroughSubject<Void, Never>()

    // Keep connection
    let didToggleKeepConnection = PassthroughSubject<Bool, Never>()

    // Alerts
    let didToggleAlert = PassthroughSubject<(AlertType, Bool), Never>()
    let didChangeAlertRange = PassthroughSubject<CardsSettingsAlertRangeChange, Never>()
    let didRequestAlertDescriptionEdit = PassthroughSubject<AlertType, Never>()
    let didRequestAlertLimitEdit = PassthroughSubject<AlertType, Never>()
    let didTapCloudConnectionDelay = PassthroughSubject<Void, Never>()
    let didTapNoValuesIndicator = PassthroughSubject<Void, Never>()

    // Offset correction actions
    let didTapTemperatureOffset = PassthroughSubject<Void, Never>()
    let didTapHumidityOffset = PassthroughSubject<Void, Never>()
    let didTapPressureOffset = PassthroughSubject<Void, Never>()

    // More info section
    let didTapMoreInfoMacAddress = PassthroughSubject<Void, Never>()
    let didTapMoreInfoTxPower = PassthroughSubject<Void, Never>()
    let didTapMoreInfoMeasurementSequence = PassthroughSubject<Void, Never>()

    // Firmware actions
    let didTapFirmwareUpdate = PassthroughSubject<Void, Never>()

    // Remove action
    let didTapRemove = PassthroughSubject<Void, Never>()
}
