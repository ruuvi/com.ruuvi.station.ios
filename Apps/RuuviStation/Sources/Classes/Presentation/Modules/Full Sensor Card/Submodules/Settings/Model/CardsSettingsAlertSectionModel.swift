import Foundation
import RuuviOntology

struct CardsSettingsAlertSectionModel: Identifiable, Equatable {
    struct HeaderState: Equatable {
        let isOn: Bool
        let mutedTill: Date?
        let alertState: AlertState?
        let showStatusLabel: Bool
    }

    let id: String
    let title: String
    let alertType: AlertType
    let headerState: HeaderState
    let configuration: CardsSettingsAlertUIConfiguration
    let isInteractionEnabled: Bool
}
