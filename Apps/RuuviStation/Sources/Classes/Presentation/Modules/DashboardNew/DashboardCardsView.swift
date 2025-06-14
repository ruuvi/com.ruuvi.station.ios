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
                .padding(.horizontal, 12)
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
                .padding(.horizontal, 12)
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
                DashboardCardImage(snapshot: snapshot)
            case .simple:
                DashboardCardPlain(snapshot: snapshot)
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
            // Title - rebuilds only when display info changes
            Text(snapshot.displayName)
                .font(.custom("Montserrat-Bold", size: 14))
                .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
                .lineLimit(2)
                .id(snapshot.displayKey) // Rebuilds when displayName changes

            Spacer(minLength: 0)

            // Alert - rebuilds only when alert state changes
//            AlertIconView(alertState: snapshot.meta.alertState)
//                .id(snapshot.alertKey) // Rebuilds when alert state changes

            Menu { /* presenter fills */ } label: {
                Image(uiImage: RuuviAsset.more3dot.image)
                    .renderingMode(.template)
                    .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
                    .padding(.top, 4)
            }
        }
    }
}

private struct CardBackground: View {
    let snapshot: SensorSnapshot

    var body: some View {
        Group {
            if let img = snapshot.background {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .id(snapshot.displayKey) // Rebuilds when background changes
            }
        }
    }
}
// MARK: - Optimized Card Styles with Granular Component Updates
private struct DashboardCardImage: View {
    let snapshot: SensorSnapshot

    var body: some View {
        HStack(spacing: 0) {
            // Background - only rebuilds when background changes
            CardBackground(snapshot: snapshot)

            VStack(alignment: .leading, spacing: 6) {
                // Header - only rebuilds when display name or alert changes
                CardHeader(snapshot: snapshot)

//                // Prominent indicator - rebuilds when indicators change
//                if let prom = snapshot.indicators.first(where: { $0.isProminent }) {
//                    ProminentIndicatorView(model: prom)
//                        .id(snapshot.indicatorKey)
//                }

                // Indicators grid - rebuilds when indicators change
                IndicatorsGrid(snapshot: snapshot)

                Spacer(minLength: 0)

                // Footer - granular updates for each component
                CardFooter(snapshot: snapshot)
            }
            .padding(8)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(RuuviColor.dashboardCardBG.color)))
    }
}

private struct DashboardCardPlain: View {
    let snapshot: SensorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header - only rebuilds when display name or alert changes
            CardHeader(snapshot: snapshot)

            // Indicators grid - rebuilds when indicators change
            IndicatorsGrid(snapshot: snapshot)

            Spacer(minLength: 0)

            // Footer - granular updates for each component
            CardFooter(snapshot: snapshot)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(RuuviColor.dashboardCardBG.color)))
    }
}

// MARK: - Micro-Components for Granular Updates
private struct TimestampView: View {
    let snapshot: SensorSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let ts = snapshot.meta.timestamp {
                Text(ts.ruuviAgo())
                    .monospacedDigit()
                    .font(.custom("Muli-Regular", size: 10))
                    .foregroundColor(Color(RuuviColor.dashboardIndicator.color).opacity(0.8))
            } else {
                Text(RuuviLocalization.Cards.UpdatedLabel.NoData.message)
                    .font(.custom("Muli-Regular", size: 10))
                    .foregroundColor(Color(RuuviColor.dashboardIndicator.color).opacity(0.8))
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

            BatteryView(snapshot: snapshot)
                .id(snapshot.batteryKey)
        }
    }
}

private struct BatteryView: View {
    let snapshot: SensorSnapshot

    var body: some View {
        if snapshot.meta.batteryLow {
            LowBatteryLevelView()
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
                    width: meta.source == .ruuviNetwork ? 22 : 16,
                    height: 22
                )
                .opacity(0.7)
                .tint(Color(RuuviColor.dashboardIndicator.color).opacity(0.8))
        }
    }
}

// MARK: - Optimized Indicator Grid with Selective Updates
private struct IndicatorsGrid: View {
    let snapshot: SensorSnapshot

    var body: some View {
        // Only rebuild when indicators actually change
        IndicatorGridContent(indicators: snapshot.indicators)
            .id(snapshot.indicatorKey)
    }
}

private struct IndicatorGridContent: View {
    let indicators: [IndicatorModel]

    private var rows: [[IndicatorModel]] {
        var temp: [[IndicatorModel]] = []
        var row: [IndicatorModel] = []
        for m in indicators {
            row.append(m)
            if row.count == 2 {
                temp.append(row); row = []
            }
        }
        if !row.isEmpty { temp.append(row) }
        return temp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.[0].id) { row in
                HStack(spacing: 8) {
                    IndicatorView(model: row[0])
                    Spacer()
                    if row.count == 2 {
                        IndicatorView(model: row[1])
                    } else {
                        Spacer(minLength: 0)
                    }
                }
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
                .font(.custom("Montserrat-Bold", size: 14))
                .foregroundColor(
                    model.alertState == .firing ? Color(RuuviColor.orangeColor.color) : Color(
                        RuuviColor.dashboardIndicator.color
                    )
                )
            if let unit = model.unit {
                Text(unit)
                    .font(.custom("Muli-Regular", size: 12))
                    .foregroundColor(
                        model.alertState == .firing ? Color(RuuviColor.orangeColor.color) : Color(
                            RuuviColor.dashboardIndicator.color
                        )
                    )
            }
        }
    }
}

// MARK: – Prominent indicator --------------------------------------------------

private struct ProminentIndicatorView: View {
    let model: IndicatorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(model.value)
                    .font(.custom("Oswald-Bold", size: 30))
                    .foregroundColor(Color.red)
//                    .foregroundColor(Color(model.tint))
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
