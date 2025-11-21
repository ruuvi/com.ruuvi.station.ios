import SwiftUI
import RuuviLocalization

private struct Constants {
    static let padding: CGFloat = 12
    static let animationDuration: Double = 0.2
    static let rotationAngle: Double = 180
}

struct CardsSettingsExpandableSectionRow<
    Section: CardsSettingsTitledSection,
    Content: View
>: View {
    let section: Section
    let isExpanded: Bool
    let isCollapsible: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header

            if isCollapsible {
                if isExpanded {
                    if #available(iOS 17.0, *) {
                        content()
                            .transition(.opacity)
                    } else {
                        content()
                    }
                }
            } else {
                content()
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text(section.title)
                .ruuviButtonLarge()
                .foregroundStyle(
                    RuuviColor.dashboardIndicator.swiftUIColor
                )

            Spacer()

            if isCollapsible {
                RuuviAsset.arrowDropDown.swiftUIImage
                    .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                    .rotationEffect(.degrees(isExpanded ? Constants.rotationAngle : 0))
                    .animation(.easeInOut(duration: Constants.animationDuration), value: isExpanded)
            }
        }
        .padding(.horizontal, Constants.padding)
        .padding(.vertical, Constants.padding)
        .background(
            RuuviColor.tagSettingsSectionHeaderColor.swiftUIColor
        )
        .contentShape(Rectangle())
        .modifier(HeaderInteractionModifier(
            isCollapsible: isCollapsible,
            onToggle: onToggle
        ))
    }
}

private struct HeaderInteractionModifier: ViewModifier {
    let isCollapsible: Bool
    let onToggle: () -> Void

    func body(content: Content) -> some View {
        if isCollapsible {
            Button(action: onToggle) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
