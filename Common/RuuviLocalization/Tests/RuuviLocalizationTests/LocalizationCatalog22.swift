import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog22: [LocalizedStringContract] = [
        .init(
            key: "TagSettings.PairAndBackgroundScan.description", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.PairAndBackgroundScan.description },
            localized: { RuuviLocalization.TagSettings.PairAndBackgroundScan.description($0) }),
        .init(
            key: "TagSettings.PairAndBackgroundScan.Paired.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.PairAndBackgroundScan.Paired.title },
            localized: { RuuviLocalization.TagSettings.PairAndBackgroundScan.Paired.title($0) }),
        .init(
            key: "TagSettings.PairAndBackgroundScan.Pairing.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.PairAndBackgroundScan.Pairing.title },
            localized: { RuuviLocalization.TagSettings.PairAndBackgroundScan.Pairing.title($0) }),
        .init(
            key: "TagSettings.PairAndBackgroundScan.Unpaired.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.PairAndBackgroundScan.Unpaired.title },
            localized: { RuuviLocalization.TagSettings.PairAndBackgroundScan.Unpaired.title($0) }),
        .init(
            key: "TagSettings.PairError.CloudMode.description", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.PairError.CloudMode.description },
            localized: { RuuviLocalization.TagSettings.PairError.CloudMode.description($0) }),
        .init(
            key: "TagSettings.PairError.Timeout.description", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.PairError.Timeout.description },
            localized: { RuuviLocalization.TagSettings.PairError.Timeout.description($0) }),
        .init(
            key: "TagSettings.RemoveThisSensor.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.RemoveThisSensor.title },
            localized: { RuuviLocalization.TagSettings.RemoveThisSensor.title($0) }),
        .init(
            key: "TagSettings.SectionHeader.BTConnection.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.SectionHeader.BTConnection.title },
            localized: { RuuviLocalization.TagSettings.SectionHeader.BTConnection.title($0) }),
        .init(
            key: "TagSettings.Share.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.Share.title },
            localized: { RuuviLocalization.TagSettings.Share.title($0) }),
        .init(
            key: "TagSettings.accelerationXTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.AccelerationXTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.AccelerationXTitleLabel.text($0) }),
        .init(
            key: "TagSettings.accelerationYTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.AccelerationYTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.AccelerationYTitleLabel.text($0) }),
        .init(
            key: "TagSettings.accelerationZTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.AccelerationZTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.AccelerationZTitleLabel.text($0) }),
        .init(
            key: "TagSettings.backgroundImageLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.BackgroundImageLabel.text },
            localized: { RuuviLocalization.TagSettings.BackgroundImageLabel.text($0) }),
        .init(
            key: "TagSettings.confirmTagRemovalDialog.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.ConfirmTagRemovalDialog.title },
            localized: { RuuviLocalization.TagSettings.ConfirmTagRemovalDialog.title($0) }),
        .init(
            key: "TagSettings.dataFormatTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.DataFormatTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.DataFormatTitleLabel.text($0) }),
        .init(
            key: "TagSettings.dataSourceTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.DataSourceTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.DataSourceTitleLabel.text($0) }),
        .init(
            key: "TagSettings.macAddressTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.MacAddressTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.MacAddressTitleLabel.text($0) }),
        .init(
            key: "TagSettings.msnTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.MsnTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.MsnTitleLabel.text($0) }),
        .init(
            key: "TagSettings.navigationItem.title", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.NavigationItem.title },
            localized: { RuuviLocalization.TagSettings.NavigationItem.title($0) }),
        .init(
            key: "TagSettings.tagNameTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.TagNameTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.TagNameTitleLabel.text($0) }),
        .init(
            key: "TagSettings.tagNameTitleLabel.rename.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text },
            localized: { RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text($0) }),
        .init(
            key: "TagSettings.txPowerTitleLabel.text", arguments: [],
            defaultValue: { RuuviLocalization.TagSettings.TxPowerTitleLabel.text },
            localized: { RuuviLocalization.TagSettings.TxPowerTitleLabel.text($0) }),
        .init(
            key: "TagsManagerPresenter.SignOutConfirmAlert.Message", arguments: [],
            defaultValue: { RuuviLocalization.TagsManagerPresenter.SignOutConfirmAlert.message },
            localized: { RuuviLocalization.TagsManagerPresenter.SignOutConfirmAlert.message($0) }),
        .init(
            key: "TemperatureUnit.Celsius.title", arguments: [],
            defaultValue: { RuuviLocalization.TemperatureUnit.Celsius.title },
            localized: { RuuviLocalization.TemperatureUnit.Celsius.title($0) }),
        .init(
            key: "TemperatureUnit.Fahrenheit.title", arguments: [],
            defaultValue: { RuuviLocalization.TemperatureUnit.Fahrenheit.title },
            localized: { RuuviLocalization.TemperatureUnit.Fahrenheit.title($0) }),
        .init(
            key: "TemperatureUnit.Kelvin.title", arguments: [],
            defaultValue: { RuuviLocalization.TemperatureUnit.Kelvin.title },
            localized: { RuuviLocalization.TemperatureUnit.Kelvin.title($0) }),
        .init(
            key: "UnexpectedError.bothLuidAndMacAreNil", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.bothLuidAndMacAreNil },
            localized: { RuuviLocalization.UnexpectedError.bothLuidAndMacAreNil($0) }),
        .init(
            key: "UnexpectedError.callbackErrorAndResultAreNil", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.callbackErrorAndResultAreNil },
            localized: { RuuviLocalization.UnexpectedError.callbackErrorAndResultAreNil($0) }),
        .init(
            key: "UnexpectedError.callerDeinitedDuringOperation", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.callerDeinitedDuringOperation },
            localized: { RuuviLocalization.UnexpectedError.callerDeinitedDuringOperation($0) }),
        .init(
            key: "UnexpectedError.failedToFindLogsForTheTag", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.failedToFindLogsForTheTag },
            localized: { RuuviLocalization.UnexpectedError.failedToFindLogsForTheTag($0) }),
        .init(
            key: "UnexpectedError.failedToFindOrGenerateBackgroundImage", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.failedToFindOrGenerateBackgroundImage },
            localized: { RuuviLocalization.UnexpectedError.failedToFindOrGenerateBackgroundImage($0) }),
        .init(
            key: "UnexpectedError.failedToFindRuuviTag", arguments: [],
            defaultValue: { RuuviLocalization.UnexpectedError.failedToFindRuuviTag },
            localized: { RuuviLocalization.UnexpectedError.failedToFindRuuviTag($0) }),
    ]
}
