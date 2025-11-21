import Foundation
import SwiftUI

protocol CardsSettingsTitledSection: Identifiable {
    var title: String { get }
}

// MARK: - Section Models for common sections
struct CardsSettingsSection: Identifiable {
    let id: String
    let title: String
    let isCollapsible: Bool
    let content: () -> AnyView

    init(
        id: String,
        title: String,
        isCollapsible: Bool = true,
        content: @escaping () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.isCollapsible = isCollapsible
        self.content = content
    }
}

extension CardsSettingsSection: CardsSettingsTitledSection {}
