import SwiftUI

struct CardsSettingsMoreInfoRowModel: Identifiable {
    enum Action {
        case none
        case macAddress
        case txPower
        case measurementSequence
    }

    let id: String
    let title: String
    let value: String
    let note: String?
    let noteColor: Color?
    let action: Action

    var isTappable: Bool {
        action != .none
    }
}
