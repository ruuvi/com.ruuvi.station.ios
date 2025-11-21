import Foundation
import RuuviLocalization
import RuuviOntology
import SwiftUI

struct CardsSettingsMoreInfoRowBuilder {

    // swiftlint:disable:next function_body_length
    static func buildMoreInfoRows(
        from snapshot: RuuviTagCardSnapshot
    ) -> [CardsSettingsMoreInfoRowModel] {
        var rows: [CardsSettingsMoreInfoRowModel] = []
        let emptyValue = RuuviLocalization.na
        let display = snapshot.displayData

        let macValue = snapshot.identifierData.mac?.value ??
            snapshot.identifierData.luid?.value ??
            emptyValue
        rows.append(
            CardsSettingsMoreInfoRowModel(
                id: CardsSettingsMoreInfoRowID.mac.rawValue,
                title: RuuviLocalization.TagSettings.MacAddressTitleLabel.text,
                value: macValue,
                note: nil,
                noteColor: nil,
                action: .macAddress
            )
        )

        let dataFormat = formattedVersion(from: display.version)
        rows.append(
            CardsSettingsMoreInfoRowModel(
                id: CardsSettingsMoreInfoRowID.dataFormat.rawValue,
                title: RuuviLocalization.TagSettings.DataFormatTitleLabel.text,
                value: dataFormat,
                note: nil,
                noteColor: nil,
                action: .none
            )
        )

        let dataSource = formattedDataSource(from: display.source)
        rows.append(
            CardsSettingsMoreInfoRowModel(
                id: CardsSettingsMoreInfoRowID.dataSource.rawValue,
                title: RuuviLocalization.TagSettings.DataSourceTitleLabel.text,
                value: dataSource,
                note: nil,
                noteColor: nil,
                action: .none
            )
        )

        if snapshot.capabilities.showBatteryStatus {
            let (batteryValue, batteryNote, batteryColor) = formattedBatteryInfo(
                voltage: display.voltage,
                needsReplacement: display.batteryNeedsReplacement,
                firmwareVersion: display.version
            )
            rows.append(
                CardsSettingsMoreInfoRowModel(
                    id: CardsSettingsMoreInfoRowID.battery.rawValue,
                    title: RuuviLocalization.batteryVoltage,
                    value: batteryValue,
                    note: batteryNote,
                    noteColor: batteryColor,
                    action: .none
                )
            )
        }

        if let accX = display.accelerationX {
            rows.append(
                CardsSettingsMoreInfoRowModel(
                    id: CardsSettingsMoreInfoRowID.accX.rawValue,
                    title: RuuviLocalization.TagSettings.AccelerationXTitleLabel.text,
                    value: formattedAcceleration(from: accX),
                    note: nil,
                    noteColor: nil,
                    action: .none
                )
            )
        }

        if let accY = display.accelerationY {
            rows.append(
                CardsSettingsMoreInfoRowModel(
                    id: CardsSettingsMoreInfoRowID.accY.rawValue,
                    title: RuuviLocalization.TagSettings.AccelerationYTitleLabel.text,
                    value: formattedAcceleration(from: accY),
                    note: nil,
                    noteColor: nil,
                    action: .none
                )
            )
        }

        if let accZ = display.accelerationZ {
            rows.append(
                CardsSettingsMoreInfoRowModel(
                    id: CardsSettingsMoreInfoRowID.accZ.rawValue,
                    title: RuuviLocalization.TagSettings.AccelerationZTitleLabel.text,
                    value: formattedAcceleration(from: accZ),
                    note: nil,
                    noteColor: nil,
                    action: .none
                )
            )
        }

        if let txPower = display.txPower {
            rows.append(
                CardsSettingsMoreInfoRowModel(
                    id: CardsSettingsMoreInfoRowID.txPower.rawValue,
                    title: RuuviLocalization.TagSettings.TxPowerTitleLabel.text,
                    value: formattedTxPower(from: txPower),
                    note: nil,
                    noteColor: nil,
                    action: .txPower
                )
            )
        }

        let rssiValue = formattedRSSI(from: display.latestRSSI)
        rows.append(
            CardsSettingsMoreInfoRowModel(
                id: CardsSettingsMoreInfoRowID.rssi.rawValue,
                title: RuuviLocalization.signalStrengthWithUnit,
                value: rssiValue,
                note: nil,
                noteColor: nil,
                action: .none
            )
        )

        let measurementSequence = display.measurementSequenceNumber
            .map { "\($0)" } ?? emptyValue
        rows.append(
            CardsSettingsMoreInfoRowModel(
                id: CardsSettingsMoreInfoRowID.measurementSequenceNumber.rawValue,
                title: RuuviLocalization.TagSettings.MsnTitleLabel.text,
                value: measurementSequence,
                note: nil,
                noteColor: nil,
                action: .measurementSequence
            )
        )

        return rows
    }
}

// MARK: - Formatting
extension CardsSettingsMoreInfoRowBuilder {
    static func formattedVersion(from value: Int?) -> String {
        guard let value else { return RuuviLocalization.na }
        switch value {
        case 0xC5:
            return "C5"
        case 0xE1:
            return "E1"
        case 0x06:
            return "6"
        default:
            return "\(value)"
        }
    }

    static func formattedDataSource(from source: RuuviTagSensorRecordSource?) -> String {
        guard let source else { return RuuviLocalization.na }
        switch source {
        case .advertisement, .bgAdvertisement:
            return RuuviLocalization.TagSettings.DataSource.Advertisement.title
        case .heartbeat, .log:
            return RuuviLocalization.TagSettings.DataSource.Heartbeat.title
        case .ruuviNetwork:
            return RuuviLocalization.TagSettings.DataSource.Network.title
        default:
            return RuuviLocalization.na
        }
    }

    static func formattedBatteryInfo(
        voltage: Double?,
        needsReplacement: Bool,
        firmwareVersion: Int?
        // swiftlint:disable:next large_tuple
    ) -> (String, String?, Color?) {
        let value: String
        if let voltage {
            value = String.localizedStringWithFormat("%.3f", voltage) + " " + RuuviLocalization.v
        } else {
            value = RuuviLocalization.na
        }

        let firmware = RuuviDataFormat.dataFormat(from: firmwareVersion ?? 0)
        if firmware == .e1 || firmware == .v6 {
            return (value, nil, nil)
        }

        let status = needsReplacement
            ? "(\(RuuviLocalization.TagSettings.BatteryStatusLabel.Replace.message))"
            : "(\(RuuviLocalization.TagSettings.BatteryStatusLabel.Ok.message))"
        let color = needsReplacement
            ? Color(RuuviColor.orangeColor.color)
            : Color(RuuviColor.tintColor.color)
        return (value, status, color)
    }

    static func formattedAcceleration(from value: Double) -> String {
        String.localizedStringWithFormat("%.3f", value) + " " + RuuviLocalization.g
    }

    static func formattedTxPower(from value: Int) -> String {
        "\(value) \(RuuviLocalization.dBm)"
    }

    static func formattedRSSI(from value: Int?) -> String {
        guard let value else { return RuuviLocalization.na }
        return "\(value) \(RuuviLocalization.dBm)"
    }
}
