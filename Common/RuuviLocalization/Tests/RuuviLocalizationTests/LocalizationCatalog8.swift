import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog8: [LocalizedStringContract] = [
        .init(
            key: "meas_seq_number", arguments: [],
            defaultValue: { RuuviLocalization.measSeqNumber },
            localized: { RuuviLocalization.measSeqNumber($0) }),
        .init(
            key: "min", arguments: [],
            defaultValue: { RuuviLocalization.min },
            localized: { RuuviLocalization.min($0) }),
        .init(
            key: "more", arguments: [],
            defaultValue: { RuuviLocalization.more },
            localized: { RuuviLocalization.more($0) }),
        .init(
            key: "more_info", arguments: [],
            defaultValue: { RuuviLocalization.moreInfo },
            localized: { RuuviLocalization.moreInfo($0) }),
        .init(
            key: "move_down", arguments: [],
            defaultValue: { RuuviLocalization.moveDown },
            localized: { RuuviLocalization.moveDown($0) }),
        .init(
            key: "move_up", arguments: [],
            defaultValue: { RuuviLocalization.moveUp },
            localized: { RuuviLocalization.moveUp($0) }),
        .init(
            key: "movement_counter", arguments: [],
            defaultValue: { RuuviLocalization.movementCounter },
            localized: { RuuviLocalization.movementCounter($0) }),
        .init(
            key: "movements", arguments: [],
            defaultValue: { RuuviLocalization.movements },
            localized: { RuuviLocalization.movements($0) }),
        .init(
            key: "my_account_change_email", arguments: [],
            defaultValue: { RuuviLocalization.myAccountChangeEmail },
            localized: { RuuviLocalization.myAccountChangeEmail($0) }),
        .init(
            key: "my_account_change_email_link", arguments: [],
            defaultValue: { RuuviLocalization.myAccountChangeEmailLink },
            localized: { RuuviLocalization.myAccountChangeEmailLink($0) }),
        .init(
            key: "my_account_change_email_link_markup", arguments: [],
            defaultValue: { RuuviLocalization.myAccountChangeEmailLinkMarkup },
            localized: { RuuviLocalization.myAccountChangeEmailLinkMarkup($0) }),
        .init(
            key: "N/A", arguments: [],
            defaultValue: { RuuviLocalization.na },
            localized: { RuuviLocalization.na($0) }),
        .init(
            key: "name", arguments: [],
            defaultValue: { RuuviLocalization.name },
            localized: { RuuviLocalization.name($0) }),
        .init(
            key: "network_sharing_disabled", arguments: [],
            defaultValue: { RuuviLocalization.networkSharingDisabled },
            localized: { RuuviLocalization.networkSharingDisabled($0) }),
        .init(
            key: "newsletter_card_description", arguments: [],
            defaultValue: { RuuviLocalization.newsletterCardDescription },
            localized: { RuuviLocalization.newsletterCardDescription($0) }),
        .init(
            key: "newsletter_card_title", arguments: [],
            defaultValue: { RuuviLocalization.newsletterCardTitle },
            localized: { RuuviLocalization.newsletterCardTitle($0) }),
        .init(
            key: "newsletter_subscribe", arguments: [],
            defaultValue: { RuuviLocalization.newsletterSubscribe },
            localized: { RuuviLocalization.newsletterSubscribe($0) }),
        .init(
            key: "newsletter_subscription", arguments: [],
            defaultValue: { RuuviLocalization.newsletterSubscription },
            localized: { RuuviLocalization.newsletterSubscription($0) }),
        .init(
            key: "newsletter_subscription_confirmation", arguments: [],
            defaultValue: { RuuviLocalization.newsletterSubscriptionConfirmation },
            localized: { RuuviLocalization.newsletterSubscriptionConfirmation($0) }),
        .init(
            key: "newsletter_url", arguments: [],
            defaultValue: { RuuviLocalization.newsletterUrl },
            localized: { RuuviLocalization.newsletterUrl($0) }),
        .init(
            key: "next_sensor", arguments: [],
            defaultValue: { RuuviLocalization.nextSensor },
            localized: { RuuviLocalization.nextSensor($0) }),
        .init(
            key: "nitrogen_oxides", arguments: [],
            defaultValue: { RuuviLocalization.nitrogenOxides },
            localized: { RuuviLocalization.nitrogenOxides($0) }),
        .init(
            key: "No", arguments: [],
            defaultValue: { RuuviLocalization.no },
            localized: { RuuviLocalization.no($0) }),
        .init(
            key: "no_password_needed", arguments: [],
            defaultValue: { RuuviLocalization.noPasswordNeeded },
            localized: { RuuviLocalization.noPasswordNeeded($0) }),
        .init(
            key: "note", arguments: [],
            defaultValue: { RuuviLocalization.note },
            localized: { RuuviLocalization.note($0) }),
        .init(
            key: "notes", arguments: [],
            defaultValue: { RuuviLocalization.notes },
            localized: { RuuviLocalization.notes($0) }),
        .init(
            key: "nox", arguments: [],
            defaultValue: { RuuviLocalization.nox },
            localized: { RuuviLocalization.nox($0) }),
        .init(
            key: "nox_with_unit", arguments: ["Sensor 1 🌡️"],
            defaultValue: { RuuviLocalization.noxWithUnit("Sensor 1 🌡️") },
            localized: { RuuviLocalization.noxWithUnit("Sensor 1 🌡️", $0) }),
        .init(
            key: "Off", arguments: [],
            defaultValue: { RuuviLocalization.off },
            localized: { RuuviLocalization.off($0) }),
        .init(
            key: "offset_correction", arguments: [],
            defaultValue: { RuuviLocalization.offsetCorrection },
            localized: { RuuviLocalization.offsetCorrection($0) }),
        .init(
            key: "OK", arguments: [],
            defaultValue: { RuuviLocalization.ok },
            localized: { RuuviLocalization.ok($0) }),
        .init(
            key: "On", arguments: [],
            defaultValue: { RuuviLocalization.on },
            localized: { RuuviLocalization.on($0) }),
    ]
}
