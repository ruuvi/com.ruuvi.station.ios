import SwiftUI
import RuuviLocalization
import SwiftUIMasonry
import RuuviOntology
import Dragula

// MARK: – Dashboard masonry ----------------------------------------------------

@available(iOS 17.0, *)
struct DashboardCardsView: View {
    @State var store: ModernSensorStore
    @EnvironmentObject var viewState: DashboardViewState

    @State private var localSnapshots: [SensorSnapshot] = []

    @State private var isDragging: Bool = false

    @Environment(\.verticalSizeClass) private var vSize

    private func columns(for geo: GeometryProxy) -> Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return geo.size.width > geo.size.height ? 3 : 2
        } else {
            return vSize == .compact ? 2 : 1
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cols = columns(for: geo)

            ScrollView(.vertical, showsIndicators: false) {
                VMasonry(columns: cols, spacing: 8) {
                    DragulaView(items: $localSnapshots) { snapshot in
                        CardHost(snapshot: snapshot)
                            .equatable()
                            .id(snapshot.id)
                    } dropView: { snapshot in
                        CardHost(snapshot: snapshot)
                            .equatable()
                            .id(snapshot.id)
                    } dragWillBegin: {
                        isDragging = true
                    } dropCompleted: {
                        let newOrder = localSnapshots.map(\.id)
                        Task { @MainActor in
                            store.reorder(by: newOrder)
                            isDragging = false
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: cols)
                .padding(.horizontal, 14)
            }
            .onAppear {
                localSnapshots = store.snapshots
            }
            .onChange(of: store.snapshots) { _, newValue in
                if !isDragging {
                    localSnapshots = newValue
                }
            }
        }
    }
}

struct DashboardCardsViewLegacy: View {
    @StateObject var store: LegacySensorStore
    @EnvironmentObject var viewState: DashboardViewState

    @State private var localSnapshots: [SensorSnapshot] = []

    @State private var isDragging: Bool = false

    @Environment(\.verticalSizeClass) private var vSize

    private func columns(for geo: GeometryProxy) -> Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return geo.size.width > geo.size.height ? 3 : 2
        } else {
            return vSize == .compact ? 2 : 1
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cols = columns(for: geo)

            ScrollView(.vertical, showsIndicators: false) {
                VMasonry(columns: cols, spacing: 8) {
                    DragulaView(items: $localSnapshots) { snapshot in
                        CardHost(snapshot: snapshot)
                            .equatable()
                            .id(snapshot.id)
                            .onTapGesture {
                                // TODO: Implement tap
                            }
                    } dropView: { snapshot in
                        CardHost(snapshot: snapshot)
                            .equatable()
                            .id(snapshot.id)
                    } dragWillBegin: {
                        isDragging = true
                    } dropCompleted: {
                        // TODO: Implement Reorder
                        let newOrder = localSnapshots.map(\.id)
                        Task { @MainActor in
                            store.reorder(by: newOrder)
                            isDragging = false
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: cols)
                .padding(.horizontal, 14)
            }
            .onAppear {
                localSnapshots = store.snapshots
            }
            .onReceive(store.$snapshots) { snapshots in
                if !isDragging {
                    localSnapshots = snapshots
                }
            }
        }
    }
}

// MARK: - Optimized Card Host with Selective Updates
private struct CardHost: View, Equatable {
    let snapshot: SensorSnapshot
    @EnvironmentObject private var viewState: DashboardViewState

    var body: some View {
        Group {
            switch viewState.dashboardType {
            case .image:
                DashboardCardImage(
                    snapshot: snapshot,
                    dashboardType: viewState.dashboardType
                )
            case .simple:
                DashboardCardPlain(
                    snapshot: snapshot,
                    dashboardType: viewState.dashboardType
                )
            }
        }
        .transition(.opacity)
    }

    // Custom equatable to prevent unnecessary rebuilds
    static func == (lhs: CardHost, rhs: CardHost) -> Bool {
        return lhs.snapshot == rhs.snapshot
    }
}

// MARK: - Optimized Card Components with Granular Updates
private struct CardHeader: View {
    let snapshot: SensorSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(snapshot.displayName)
                .font(.Montserrat(.bold, size: 14))
                .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
                .lineLimit(2)
                .id(snapshot.displayKey)

            Spacer(minLength: 0)

            // TODO: Implement alerts and menu actions
            // Alert - rebuilds only when alert state changes
//            AlertIconView(alertState: snapshot.meta.alertState)
//                .id(snapshot.alertKey) // Rebuilds when alert state changes

//            Menu { /* presenter fills */ } label: {
//                Image(uiImage: RuuviAsset.more3dot.image)
//                    .renderingMode(.template)
//                    .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
//                    .padding(.top, 4)
//            }
        }
    }
}

private struct CardBackground: View {
    let snapshot: SensorSnapshot

    var body: some View {
        CardsBackgroundViewWrapper(
            image: snapshot.background
        )
        .clipped()
        .id(snapshot.displayKey)
    }
}

struct CardsBackgroundViewWrapper: UIViewRepresentable {
    var image: UIImage?
    var animate: Bool = true

    func makeUIView(context: Context) -> CardsBackgroundView {
        let view = CardsBackgroundView()
        view.setBackgroundImage(with: image, withAnimation: false)
        return view
    }

    func updateUIView(_ uiView: CardsBackgroundView, context: Context) {
        uiView.setBackgroundImage(with: image, withAnimation: animate)
    }
}

// MARK: - Image Card Styles with Granular Component Updates
private struct DashboardCardImage: View {
    let snapshot: SensorSnapshot
    let dashboardType: DashboardType

    var body: some View {
        HStack(spacing: 0) {
            CardBackground(snapshot: snapshot)
                .aspectRatio(contentMode: .fill)
                .frame(width: 110)
                .cornerRadius(8, corners: [.topLeft, .bottomLeft])

            VStack(alignment: .leading, spacing: 8) {
                CardHeader(snapshot: snapshot)
                if let prominentIndicator = snapshot.indicators.first(
                    where: {
                        $0.isProminent
                    }) {
                    ProminentIndicatorView(model: prominentIndicator)
                }
                IndicatorsGrid(
                    snapshot: snapshot,
                    dashboardType: dashboardType
                )
                CardFooter(snapshot: snapshot)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(RuuviColor.dashboardCardBG.swiftUIColor)
        )
//        .frame(minHeight: 100) // TODO: Discuss this with Denis.
    }
}

private struct DashboardCardPlain: View {
    let snapshot: SensorSnapshot
    let dashboardType: DashboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(snapshot: snapshot)
            IndicatorsGrid(
                snapshot: snapshot,
                dashboardType: dashboardType
            )
            CardFooter(snapshot: snapshot)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(RuuviColor.dashboardCardBG.swiftUIColor)
        )
    }
}

// MARK: - Micro-Components for Granular Updates
private struct TimestampView: View {
    let snapshot: SensorSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let timestamp = snapshot.meta.timestamp {
                Text(timestamp.ruuviAgo())
                    .monospacedDigit()
                    .font(.Muli(.regular, size: 10))
                    .foregroundColor(
                        RuuviColor.dashboardIndicator.swiftUIColor.opacity(0.8)
                    )
            } else {
                Text(RuuviLocalization.Cards.UpdatedLabel.NoData.message)
                    .font(.Muli(.regular, size: 10))
                    .foregroundColor(
                        RuuviColor.dashboardIndicator.swiftUIColor.opacity(0.8)
                    )
            }
        }
    }
}

private struct CardFooter: View {
    let snapshot: SensorSnapshot

    var body: some View {
        HStack(spacing: 6) {
            SourceIconView(meta: snapshot.meta)
            TimestampView(snapshot: snapshot)
                .id(snapshot.timestampKey)
            Spacer(minLength: 0)
            if snapshot.meta.batteryLow {
                LowBatteryLevelView()
                    .id(snapshot.batteryKey)
            }
        }
    }
}

private struct SourceIconView: View {
    let meta: SensorSnapshot.Meta

    var body: some View {
        if let icon = meta.sourceIcon {
            icon
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: meta.source == .ruuviNetwork ? 20 : 16
                )
                .opacity(0.7)
                .foregroundStyle(
                    RuuviColor.dashboardIndicator.swiftUIColor.opacity(0.8)
                )
        }
    }
}

// MARK: - Optimized Indicator Grid with Selective Updates
private struct IndicatorsGrid: View {
    let snapshot: SensorSnapshot
    let dashboardType: DashboardType

    var body: some View {
        IndicatorGridContent(
            indicators: dashboardType == .simple ?
                snapshot.indicators :
                snapshot.indicators.filter({ !$0.isProminent })
        )
        .id(snapshot.indicatorKey)
    }
}

private struct IndicatorGridContent: View {
    let indicators: [IndicatorModel]

    private var columns: [GridItem] {
        return indicators.count <= 2 ?
                [GridItem(.flexible(minimum: 0))] :
                [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
            ForEach(indicators) { indicator in
                IndicatorView(model: indicator)
            }
        }
    }
}

// MARK: – Indicator  -----------------------------------------------------------

private struct IndicatorView: View {
    let model: IndicatorModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(model.value)
                .font(.Montserrat(.bold, size: 14))
                .lineLimit(1)
                .foregroundColor(
                    model.alertState == .firing ?
                        Color(RuuviColor.orangeColor.color) :
                        Color(RuuviColor.dashboardIndicator.color)
                )
                .multilineTextAlignment(.leading)
            if let unit = model.unit {
                Text(unit)
                    .font(.Muli(.regular, size: 12))
                    .lineLimit(1)
                    .foregroundColor(
                        model.alertState == .firing ?
                            Color(RuuviColor.orangeColor.color) :
                            Color(RuuviColor.dashboardIndicator.color)
                    )
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

// MARK: – Prominent indicator --------------------------------------------------

private struct ProminentIndicatorView: View {
    let model: IndicatorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(model.value)
                    .font(
                        .Oswald(.bold, size: 30)
                    )
                    .foregroundColor(
                        model.alertState == .firing ?
                            Color(RuuviColor.orangeColor.color) :
                            Color(RuuviColor.dashboardIndicator.color)
                    )
                    .multilineTextAlignment(.leading)

//                if let sup = model.superscript {
//                    Text(sup)
//                        .font(.custom("Oswald-Regular", size: 12))
////                        .foregroundColor(model.tint)
//                        .baselineOffset(4)
//                }
            }
//            if let sub = model.subscriptValue {
//                Text(sub)
//                    .font(.custom("Muli-Bold", size: 12))
//                    .foregroundColor(Color(RuuviColor.dashboardIndicator.color).opacity(0.6))
//            }
            if let progress = model.progress {
                ProgressView(value: Double(progress))
//                    .progressViewStyle(LinearProgressViewStyle(tint: model.tint))
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.red))
                    .frame(maxWidth: 120)
            }
        }
    }
}


// MARK: - Alert Icon View
struct AlertIconView: View {
    let alertState: AlertState?
    @State private var isAlertFiring = false

    var body: some View {
        if alertState != .empty {
            Image(uiImage: alertIconImage)
                .renderingMode(.template)
                .foregroundColor(alertIconColor)
                .opacity(isAlertFiring ? 0 : 1)
                .frame(width: 24, height: 18)
                .onAppear {
                    if alertState == .firing {
                        withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            isAlertFiring.toggle()
                        }
                    }
                }
        }
    }

    private var alertIconImage: UIImage {
        switch alertState {
        case .registered:
            return RuuviAsset.iconAlertOn.image
        case .firing:
            return RuuviAsset.iconAlertActive.image
        default:
            return UIImage()
        }
    }

    private var alertIconColor: Color {
        switch alertState {
        case .registered:
            return RuuviColor.logoTintColor.swiftUIColor
        case .firing:
            return RuuviColor.orangeColor.swiftUIColor
        default:
            return .clear
        }
    }
}

struct CornerRadiusStyle: ViewModifier {
    var radius: CGFloat
    var corners: UIRectCorner

    struct CornerRadiusShape: Shape {

        var radius = CGFloat.infinity
        var corners = UIRectCorner.allCorners

        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
            return Path(path.cgPath)
        }
    }

    func body(content: Content) -> some View {
        content
            .clipShape(CornerRadiusShape(radius: radius, corners: corners))
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        ModifiedContent(content: self, modifier: CornerRadiusStyle(radius: radius, corners: corners))
    }
}
