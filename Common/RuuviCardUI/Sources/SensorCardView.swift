#if os(iOS)
import RuuviLocalization
#endif
import SwiftUI

public enum SensorCardViewStyle {
    case compact
    case dashboardSimple
}

/// Shared sensor card view used by both the Watch app and the Widgets extension.
///
/// Callers pre-compute `items` (for example in the watch sensor model or in
/// `WidgetViewModel.indicators(...)`) and pass the formatted strings in.
public struct SensorCardView: View {
    let displayName: String
    let formattedUpdatedAt: String
    let items: [SensorMeasurementItem]
    let style: SensorCardViewStyle

    public init(
        displayName: String,
        formattedUpdatedAt: String,
        items: [SensorMeasurementItem],
        style: SensorCardViewStyle = .compact
    ) {
        self.displayName       = displayName
        self.formattedUpdatedAt = formattedUpdatedAt
        self.items             = items
        self.style             = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Sensor name ────────────────────────────────────────
            Text(displayName)
                .font(CardStyle.nameFont)
                .foregroundStyle(CardStyle.primary)
                .lineLimit(2)
                .padding(.bottom, 8)

            // ── 2-column measurement grid ──────────────────────────
            if !items.isEmpty {
                let rows = stride(from: 0, to: items.count, by: 2).map {
                    Array(items[$0 ..< min($0 + 2, items.count)])
                }
                VStack(alignment: .leading, spacing: style == .dashboardSimple ? 0 : 4) {
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(rows[rowIndex]) { item in
                                MeasurementCell(item: item, style: style)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(
                                        minHeight: style == .dashboardSimple ? CardStyle.dashboardRowHeight : nil,
                                        alignment: .leading
                                    )
                            }
                            if rows[rowIndex].count < 2 {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }

            // ── Footer: last-updated ───────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 9))
                Text(formattedUpdatedAt)
                    .font(CardStyle.timestampFont)
            }
            .foregroundStyle(CardStyle.secondary)
            .padding(.top, style == .dashboardSimple ? 8 : 6)
        }
        .padding(
            EdgeInsets(
                top: style == .dashboardSimple ? 12 : 10,
                leading: style == .dashboardSimple ? 16 : 12,
                bottom: style == .dashboardSimple ? 4 : 10,
                trailing: style == .dashboardSimple ? 10 : 12
            )
        )
        .background(CardStyle.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Measurement cell

private struct MeasurementCell: View {
    let item: SensorMeasurementItem
    let style: SensorCardViewStyle

    var body: some View {
        Group {
            if style == .dashboardSimple {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(item.value)
                        .font(CardStyle.valueFont)
                        .foregroundStyle(CardStyle.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if !item.unit.isEmpty {
                        Text(item.unit)
                            .font(CardStyle.dashboardUnitFont)
                            .foregroundStyle(CardStyle.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Text(item.label)
                        .font(CardStyle.dashboardLabelFont)
                        .foregroundStyle(CardStyle.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label)
                        .font(CardStyle.labelFont)
                        .foregroundStyle(CardStyle.secondary)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(item.value)
                            .font(CardStyle.valueFont)
                            .foregroundStyle(CardStyle.primary)
                            .lineLimit(1)
                        if !item.unit.isEmpty {
                            Text(item.unit)
                                .font(CardStyle.unitFont)
                                .foregroundStyle(CardStyle.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Style tokens

private enum CardStyle {
    static let background = Color(red: 25/255, green: 59/255, blue: 60/255)
    static let primary    = Color.white
    static let secondary  = Color.white.opacity(0.5)

#if os(watchOS)
    static let nameFont          = Font.custom("Mulish-ExtraBold", size: 15)
    static let valueFont         = Font.custom("Mulish-ExtraBold", size: 12)
    static let unitFont          = Font.custom("Mulish-Bold", size: 9)
    static let labelFont         = Font.custom("Mulish-Regular", size: 8)
    static let dashboardLabelFont = Font.custom("Mulish-Regular", size: 8)
    static let dashboardUnitFont = Font.custom("Mulish-Bold", size: 8)
    static let timestampFont     = Font.custom("Mulish-Regular", size: 10)
    static let dashboardRowHeight: CGFloat = 18
#else
    static let nameFont          = Font.mulish(.extraBold, size: 16, relativeTo: .headline)
    static let valueFont         = Font.mulish(.extraBold, size: 14, relativeTo: .body)
    static let unitFont          = Font.mulish(.bold,      size: 10, relativeTo: .caption2)
    static let labelFont         = Font.mulish(.regular,   size: 8,  relativeTo: .caption2)
    static let dashboardLabelFont = Font.mulish(.regular,  size: 10, relativeTo: .caption2)
    static let dashboardUnitFont = Font.mulish(.bold,      size: 10, relativeTo: .caption2)
    static let timestampFont     = Font.mulish(.regular,   size: 10, relativeTo: .body)
    static let dashboardRowHeight: CGFloat = 20
#endif
}
