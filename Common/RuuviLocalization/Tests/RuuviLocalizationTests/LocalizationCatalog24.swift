import Foundation
import RuuviLocalization

extension LocalizationCatalog {
    static let catalog24: [LocalizedStringContract] = [
        .init(
            key: "UserApiError.ER_SUBSCRIPTION_CODE_EXISTS", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSubscriptionCodeExists },
            localized: { RuuviLocalization.UserApiError.erSubscriptionCodeExists($0) }),
        .init(
            key: "UserApiError.ER_SUBSCRIPTION_CODE_USED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSubscriptionCodeUsed },
            localized: { RuuviLocalization.UserApiError.erSubscriptionCodeUsed($0) }),
        .init(
            key: "UserApiError.ER_SUBSCRIPTION_NOT_FOUND", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erSubscriptionNotFound },
            localized: { RuuviLocalization.UserApiError.erSubscriptionNotFound($0) }),
        .init(
            key: "UserApiError.ER_THROTTLED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erThrottled },
            localized: { RuuviLocalization.UserApiError.erThrottled($0) }),
        .init(
            key: "UserApiError.ER_TOKEN_EXPIRED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erTokenExpired },
            localized: { RuuviLocalization.UserApiError.erTokenExpired($0) }),
        .init(
            key: "UserApiError.ER_UNABLE_TO_SEND_EMAIL", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erUnableToSendEmail },
            localized: { RuuviLocalization.UserApiError.erUnableToSendEmail($0) }),
        .init(
            key: "UserApiError.ER_UNAUTHORIZED", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erUnauthorized },
            localized: { RuuviLocalization.UserApiError.erUnauthorized($0) }),
        .init(
            key: "UserApiError.ER_USER_NOT_FOUND", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.erUserNotFound },
            localized: { RuuviLocalization.UserApiError.erUserNotFound($0) }),
        .init(
            key: "UserApiError.OK", arguments: [],
            defaultValue: { RuuviLocalization.UserApiError.ok },
            localized: { RuuviLocalization.UserApiError.ok($0) }),
        .init(
            key: "Widgets.Description.message", arguments: [],
            defaultValue: { RuuviLocalization.Widgets.Description.message },
            localized: { RuuviLocalization.Widgets.Description.message($0) }),
        .init(
            key: "Widgets.Loading.message", arguments: [],
            defaultValue: { RuuviLocalization.Widgets.Loading.message },
            localized: { RuuviLocalization.Widgets.Loading.message($0) }),
        .init(
            key: "Widgets.Refresh.Manual.title", arguments: [],
            defaultValue: { RuuviLocalization.Widgets.Refresh.Manual.title },
            localized: { RuuviLocalization.Widgets.Refresh.Manual.title($0) }),
        .init(
            key: "Widgets.Unconfigured.Circular.message", arguments: [],
            defaultValue: { RuuviLocalization.Widgets.Unconfigured.Circular.message },
            localized: { RuuviLocalization.Widgets.Unconfigured.Circular.message($0) }),
        .init(
            key: "Widgets.Unconfigured.Inline.message", arguments: [],
            defaultValue: { RuuviLocalization.Widgets.Unconfigured.Inline.message },
            localized: { RuuviLocalization.Widgets.Unconfigured.Inline.message($0) }),
        .init(
            key: "Widgets.Unconfigured.Rectangular.message", arguments: [],
            defaultValue: { RuuviLocalization.Widgets.Unconfigured.Rectangular.message },
            localized: { RuuviLocalization.Widgets.Unconfigured.Rectangular.message($0) }),
        .init(
            key: "Widgets.Unconfigured.Simple.message", arguments: [],
            defaultValue: { RuuviLocalization.Widgets.Unconfigured.Simple.message },
            localized: { RuuviLocalization.Widgets.Unconfigured.Simple.message($0) }),
    ]
}
