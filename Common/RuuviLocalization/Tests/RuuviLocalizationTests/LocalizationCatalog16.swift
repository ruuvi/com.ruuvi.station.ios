import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog16: [LocalizedStringContract] = [
        .init(
            key: "Defaults.IncludeDataSourceInHistoryExport.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.IncludeDataSourceInHistoryExport.title },
            localized: { RuuviLocalization.Defaults.IncludeDataSourceInHistoryExport.title($0) }),
        .init(
            key: "Defaults.Interval.Hour.string", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.Interval.Hour.string },
            localized: { RuuviLocalization.Defaults.Interval.Hour.string($0) }),
        .init(
            key: "Defaults.Interval.Min.string", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.Interval.Min.string },
            localized: { RuuviLocalization.Defaults.Interval.Min.string($0) }),
        .init(
            key: "Defaults.Interval.Sec.string", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.Interval.Sec.string },
            localized: { RuuviLocalization.Defaults.Interval.Sec.string($0) }),
        .init(
            key: "Defaults.NetworkPullingInterval.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.NetworkPullingInterval.title },
            localized: { RuuviLocalization.Defaults.NetworkPullingInterval.title($0) }),
        .init(
            key: "Defaults.PruningOffsetHours.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.PruningOffsetHours.title },
            localized: { RuuviLocalization.Defaults.PruningOffsetHours.title($0) }),
        .init(
            key: "Defaults.ServiceTimeout.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ServiceTimeout.title },
            localized: { RuuviLocalization.Defaults.ServiceTimeout.title($0) }),
        .init(
            key: "Defaults.ShowAlertRangeInCharts.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ShowAlertRangeInCharts.title },
            localized: { RuuviLocalization.Defaults.ShowAlertRangeInCharts.title($0) }),
        .init(
            key: "Defaults.ShowStatusLabelSettings.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.ShowStatusLabelSettings.title },
            localized: { RuuviLocalization.Defaults.ShowStatusLabelSettings.title($0) }),
        .init(
            key: "Defaults.TOSAccepted.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.TOSAccepted.title },
            localized: { RuuviLocalization.Defaults.TOSAccepted.title($0) }),
        .init(
            key: "Defaults.UseNewChart.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.UseNewChart.title },
            localized: { RuuviLocalization.Defaults.UseNewChart.title($0) }),
        .init(
            key: "Defaults.UserAuthorized.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.UserAuthorized.title },
            localized: { RuuviLocalization.Defaults.UserAuthorized.title($0) }),
        .init(
            key: "Defaults.WebPullInterval.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.WebPullInterval.title },
            localized: { RuuviLocalization.Defaults.WebPullInterval.title($0) }),
        .init(
            key: "Defaults.WelcomeShown.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.WelcomeShown.title },
            localized: { RuuviLocalization.Defaults.WelcomeShown.title($0) }),
        .init(
            key: "Defaults.WidgetsRefreshInterval.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.WidgetsRefreshInterval.title },
            localized: { RuuviLocalization.Defaults.WidgetsRefreshInterval.title($0) }),
        .init(
            key: "Defaults.navigationItem.title", arguments: [],
            defaultValue: { RuuviLocalization.Defaults.NavigationItem.title },
            localized: { RuuviLocalization.Defaults.NavigationItem.title($0) }),
        .init(
            key: "Devices.tokenId", arguments: [],
            defaultValue: { RuuviLocalization.Devices.tokenId },
            localized: { RuuviLocalization.Devices.tokenId($0) }),
        .init(
            key: "DfuDevicesScanner.Title.text", arguments: [],
            defaultValue: { RuuviLocalization.DfuDevicesScanner.Title.text },
            localized: { RuuviLocalization.DfuDevicesScanner.Title.text($0) }),
        .init(
            key: "DfuFlash.Finish.text", arguments: [],
            defaultValue: { RuuviLocalization.DfuFlash.Finish.text },
            localized: { RuuviLocalization.DfuFlash.Finish.text($0) }),
        .init(
            key: "DfuFlash.Firmware.BootloaderSize.text", arguments: [],
            defaultValue: { RuuviLocalization.DfuFlash.Firmware.BootloaderSize.text },
            localized: { RuuviLocalization.DfuFlash.Firmware.BootloaderSize.text($0) }),
        .init(
            key: "DfuFlash.Firmware.FileName.text", arguments: [],
            defaultValue: { RuuviLocalization.DfuFlash.Firmware.FileName.text },
            localized: { RuuviLocalization.DfuFlash.Firmware.FileName.text($0) }),
        .init(
            key: "DfuFlash.Firmware.Parts.text", arguments: [],
            defaultValue: { RuuviLocalization.DfuFlash.Firmware.Parts.text },
            localized: { RuuviLocalization.DfuFlash.Firmware.Parts.text($0) }),
        .init(
            key: "DfuFlash.Firmware.Size.text", arguments: [],
            defaultValue: { RuuviLocalization.DfuFlash.Firmware.Size.text },
            localized: { RuuviLocalization.DfuFlash.Firmware.Size.text($0) }),
        .init(
            key: "DfuFlash.Firmware.SoftDeviceSize.text", arguments: [],
            defaultValue: { RuuviLocalization.DfuFlash.Firmware.SoftDeviceSize.text },
            localized: { RuuviLocalization.DfuFlash.Firmware.SoftDeviceSize.text($0) }),
        .init(
            key: "DiscoverTable.BluetoothDisabledAlert.message", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.BluetoothDisabledAlert.message },
            localized: { RuuviLocalization.DiscoverTable.BluetoothDisabledAlert.message($0) }),
        .init(
            key: "DiscoverTable.BluetoothDisabledAlert.title", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.BluetoothDisabledAlert.title },
            localized: { RuuviLocalization.DiscoverTable.BluetoothDisabledAlert.title($0) }),
        .init(
            key: "DiscoverTable.GetMoreSensors.button.title", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.GetMoreSensors.Button.title },
            localized: { RuuviLocalization.DiscoverTable.GetMoreSensors.Button.title($0) }),
        .init(
            key: "DiscoverTable.NavigationItem.title", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.NavigationItem.title },
            localized: { RuuviLocalization.DiscoverTable.NavigationItem.title($0) }),
        .init(
            key: "DiscoverTable.NoDevicesSection.BluetoothDisabled.text", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.NoDevicesSection.BluetoothDisabled.text },
            localized: { RuuviLocalization.DiscoverTable.NoDevicesSection.BluetoothDisabled.text($0) }),
        .init(
            key: "DiscoverTable.NoDevicesSection.NotFound.text", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.NoDevicesSection.NotFound.text },
            localized: { RuuviLocalization.DiscoverTable.NoDevicesSection.NotFound.text($0) }),
        .init(
            key: "DiscoverTable.UpdateFirmware.message", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.UpdateFirmware.message },
            localized: { RuuviLocalization.DiscoverTable.UpdateFirmware.message($0) }),
        .init(
            key: "DiscoverTable.UpdateFirmware.title", arguments: [],
            defaultValue: { RuuviLocalization.DiscoverTable.UpdateFirmware.title },
            localized: { RuuviLocalization.DiscoverTable.UpdateFirmware.title($0) }),
    ]
}
