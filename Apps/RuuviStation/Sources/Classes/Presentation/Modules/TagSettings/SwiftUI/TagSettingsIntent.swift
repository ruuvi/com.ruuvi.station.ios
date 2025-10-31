import Foundation
import CoreGraphics
import RuuviOntology

struct TagSettingsIntent {
    var onDismiss: () -> Void = {}
    var onConfirmClaimTag: () -> Void = {}
    var onChangeBackground: () -> Void = {}
    var onRemoveTag: () -> Void = {}
    var onRenameTag: (String) -> Void = { _ in }
    var onOpenOwnerDetails: () -> Void = {}
    var onShare: () -> Void = {}
    var onOpenMacAddress: () -> Void = {}
    var onOpenTxPower: () -> Void = {}
    var onOpenMeasurementSequence: () -> Void = {}
    var onOpenNoValuesInfo: () -> Void = {}
    var onTriggerFirmwareUpdateDialog: () -> Void = {}
    var onConfirmFirmwareUpdate: () -> Void = {}
    var onIgnoreFirmwareUpdate: () -> Void = {}
    var onUpdateFirmware: () -> Void = {}
    var onToggleKeepConnection: (Bool) -> Void = { _ in }

    var onToggleAlert: (AlertType, Bool) -> Void = { _, _ in }
    var onChangeAlertLowerBound: (AlertType, CGFloat) -> Void = { _, _ in }
    var onChangeAlertUpperBound: (AlertType, CGFloat) -> Void = { _, _ in }
    var onChangeAlertDescription: (AlertType, String?) -> Void = { _, _ in }
    var onChangeCloudConnectionDuration: (Int) -> Void = { _ in }

    var onTemperatureOffset: () -> Void = {}
    var onHumidityOffset: () -> Void = {}
    var onPressureOffset: () -> Void = {}
}
