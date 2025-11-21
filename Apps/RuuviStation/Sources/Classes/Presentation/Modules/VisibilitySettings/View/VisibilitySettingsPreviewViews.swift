import SwiftUI
import RuuviLocalization
import RuuviOntology
import UIKit

private struct Constants {
    static let defaultHeight: CGFloat = 220
    static let cardCornerRadius: CGFloat = 16
    static let cardStrokeOpacity: Double = 0.08
    static let cardShadowOpacity: Double = 0.08
    static let cardShadowRadius: CGFloat = 6
    static let cardShadowOffsetX: CGFloat = 0
    static let cardShadowOffsetY: CGFloat = 3
    static let cardColumns = 1
    static let placeholderCornerRadius: CGFloat = 16
    static let placeholderHeight: CGFloat = 140
    static let placeholderOpacity: Double = 0.6
    static let placeholderTextOpacity: Double = 0.6
}

struct DashboardPreviewCard: View {
    let preview: VisibilitySettingsPreviewViewModel
    @State private var cardHeight: CGFloat = Constants.defaultHeight

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            DashboardCellPreviewRepresentable(
                snapshot: preview.snapshot,
                dashboardType: preview.dashboardType
            )
            .frame(width: width, height: cardHeight)
            .onAppear {
                updateCardHeight(
                    for: width,
                    snapshot: preview.snapshot,
                    dashboardType: preview.dashboardType
                )
            }
            .onChange(of: width) { newWidth in
                updateCardHeight(
                    for: newWidth,
                    snapshot: preview.snapshot,
                    dashboardType: preview.dashboardType
                )
            }
            .onChange(of: preview.snapshot) { newSnapshot in
                updateCardHeight(
                    for: width,
                    snapshot: newSnapshot,
                    dashboardType: preview.dashboardType
                )
            }
            .onChange(of: preview.dashboardType) { _ in
                updateCardHeight(
                    for: width,
                    snapshot: preview.snapshot,
                    dashboardType: preview.dashboardType
                )
            }
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
                .stroke(
                    RuuviColor.dashboardIndicator.swiftUIColor.opacity(Constants.cardStrokeOpacity)
                )
        )
        .shadow(
            color: Color.black.opacity(Constants.cardShadowOpacity),
            radius: Constants.cardShadowRadius,
            x: Constants.cardShadowOffsetX,
            y: Constants.cardShadowOffsetY
        )
    }

    private func height(
        for width: CGFloat,
        snapshot: RuuviTagCardSnapshot,
        dashboardType: DashboardType
    ) -> CGFloat {
        guard width > 0 else {
            return cardHeight
        }
        return DashboardCell.calculateHeight(
            for: snapshot,
            width: width,
            dashboardType: dashboardType,
            numberOfColumns: Constants.cardColumns
        )
    }

    private func updateCardHeight(
        for width: CGFloat,
        snapshot: RuuviTagCardSnapshot,
        dashboardType: DashboardType
    ) {
        let newHeight = height(
            for: width,
            snapshot: snapshot,
            dashboardType: dashboardType
        )
        guard newHeight != cardHeight else { return }
        cardHeight = newHeight
    }
}

struct PreviewPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Constants.placeholderCornerRadius)
            .fill(
                RuuviColor.tagSettingsSectionHeaderColor.swiftUIColor.opacity(Constants.placeholderOpacity)
            )
            .frame(height: Constants.placeholderHeight)
            .overlay(
                Text(RuuviLocalization.na)
                    .font(.ruuviSubheadline())
                    .foregroundStyle(
                        RuuviColor.textColor.swiftUIColor.opacity(Constants.placeholderTextOpacity)
                    )
            )
    }
}

struct DashboardCellPreviewRepresentable: UIViewRepresentable {
    let snapshot: RuuviTagCardSnapshot
    let dashboardType: DashboardType

    func makeUIView(context: Context) -> DashboardCellPreviewContainerView {
        let view = DashboardCellPreviewContainerView()
        view.configure(with: snapshot, dashboardType: dashboardType)
        return view
    }

    func updateUIView(_ uiView: DashboardCellPreviewContainerView, context: Context) {
        uiView.configure(with: snapshot, dashboardType: dashboardType)
    }
}

final class DashboardCellPreviewContainerView: UIView {
    private let cell = DashboardCell(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        cell.isUserInteractionEnabled = false
        cell.contentView.isUserInteractionEnabled = false
        addSubview(cell)
        cell.fillSuperview()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with snapshot: RuuviTagCardSnapshot, dashboardType: DashboardType) {
        cell.prepareForReuse()
        cell.configure(with: snapshot, dashboardType: dashboardType)
    }

    deinit {
        cell.prepareForReuse()
    }
}
