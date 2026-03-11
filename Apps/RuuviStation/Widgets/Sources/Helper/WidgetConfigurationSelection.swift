import Foundation
import Intents

enum WidgetConfigurationSelection {
    static let noneIdentifier = "__ruuvi_widget_none__"
    private static let noneLocalizationKey = "WidgetConfiguration.NoneOption"

    static func noneTag() -> RuuviWidgetTag {
        let tag = RuuviWidgetTag(
            identifier: noneIdentifier,
            display: Bundle.main.localizedString(
                forKey: noneLocalizationKey,
                value: "None",
                table: "RuuviWidgetsConfiguration"
            )
        )
        tag.deviceType = .unknown
        return tag
    }

    static func normalizedSensorIdentifier(
        from tag: RuuviWidgetTag?
    ) -> String? {
        normalizedSensorIdentifier(tag?.identifier)
    }

    static func normalizedSensorIdentifier(
        _ identifier: String?
    ) -> String? {
        guard
            let identifier,
            !identifier.isEmpty,
            identifier != noneIdentifier
        else {
            return nil
        }

        return identifier
    }
}
