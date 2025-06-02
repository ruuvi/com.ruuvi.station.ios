import SwiftUI
import RuuviLocalization
import RuuviOntology
import RuuviService
import SwiftUIMasonry

// MARK: - Main Dashboard View
struct DashboardView: View {
    @EnvironmentObject var state: DashboardViewState
    @GestureState private var isScrolling = false

    let measurementService: RuuviServiceMeasurement

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var isRefreshing = false
    @State private var draggedItem: CardsViewModel?

    // Single timer for time updates only
    @State private var timeUpdateTrigger = false
    private let updateTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect() // Reduced frequency

    private func calculateColumns(for width: CGFloat) -> Int {
        let cardMinWidth: CGFloat = 300
        let spacing: CGFloat = 8
        let padding: CGFloat = 16

        let availableWidth = width - (padding * 2)
        let maxColumns = max(1, Int(availableWidth / (cardMinWidth + spacing)))

        if UIDevice.current.userInterfaceIdiom == .pad {
            return min(maxColumns, horizontalSizeClass == .regular ? 3 : 2)
        } else {
            return min(maxColumns, verticalSizeClass == .compact ? 2 : 1)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VMasonry(
                    columns: calculateColumns(for: geometry.size.width),
                    spacing: 0
                ) {
                    ForEach(state.items, id: \.id) { viewModel in
                        DashboardCardView(
                            viewModel: viewModel,
                            measurementService: measurementService,
                            timeUpdateTrigger: timeUpdateTrigger
                        )
                        .environmentObject(state)
                        .id(viewModel.id)
                        .onDrag {
                            draggedItem = viewModel
                            return NSItemProvider(
                                object: viewModel.id! as NSItemProviderWriting
                            )
                        }
                        .onDrop(
                            of: [.plainText],
                            delegate: CardDropDelegate(
                                targetItem: viewModel,
                                items: $state.items,
                                draggedItem: $draggedItem
                            )
                        )
                        .padding(4)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: calculateColumns(for: geometry.size.width))
                .animation(.easeInOut(duration: 0.3), value: state.dashboardViewType) // Add animation for view type changes
            }
            .onReceive(updateTimer) { _ in
                timeUpdateTrigger.toggle()
            }
        }
    }
}

// MARK: - Card Drop Delegate (unchanged)
struct CardDropDelegate: DropDelegate {
    let targetItem: CardsViewModel
    @Binding var items: [CardsViewModel]
    @Binding var draggedItem: CardsViewModel?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              dragged != targetItem,
              let fromIndex = items.firstIndex(of: dragged),
              let toIndex = items.firstIndex(of: targetItem)
        else { return }

        if fromIndex != toIndex {
            withAnimation {
                items.move(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: (fromIndex < toIndex) ? toIndex + 1 : toIndex
                )
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

// MARK: - Background View Wrapper (unchanged)
struct CardsBackgroundViewWrapper: UIViewRepresentable {
    let backgroundImage: UIImage?
    let withAnimation: Bool

    init(backgroundImage: UIImage?, withAnimation: Bool = true) {
        self.backgroundImage = backgroundImage
        self.withAnimation = withAnimation
    }

    func makeUIView(context: Context) -> CardsBackgroundView {
        CardsBackgroundView()
    }

    func updateUIView(_ uiView: CardsBackgroundView, context: Context) {
        uiView.setBackgroundImage(with: backgroundImage, withAnimation: withAnimation)
    }
}

// MARK: - Simplified Dashboard Card View
struct DashboardCardView: View {
    @EnvironmentObject var state: DashboardViewState
    @ObservedObject var viewModel: CardsViewModel
    let measurementService: RuuviServiceMeasurement?
    let timeUpdateTrigger: Bool

    // Cache for expensive computations
    @State private var prominentValueCache: ProminentValueData?
    @State private var indicatorsCache: [IndicatorData] = []
    @State private var updatedAtText: String = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(RuuviColor.dashboardCardBG.color))

            HStack {
                if state.dashboardViewType == .image,
                   let background = viewModel.background {
                    CardsBackgroundViewWrapper(backgroundImage: background)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 110)
                        .clipped()
                        .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                }

                VStack(alignment: .leading, spacing: 8) {
                    CardHeaderView(viewModel: viewModel)

                    if let prominentValue = prominentValueCache {
                        ProminentValueView(data: prominentValue)
                    }

                    IndicatorGridView(indicators: indicatorsCache)

                    CardFooterView(
                        viewModel: viewModel,
                        updatedAtText: updatedAtText
                    )
                }
            }
        }
        .onAppear {
            computeData()
            updateTimeText()
        }
        .onChange(of: viewModel.temperature) { _ in computeData() }
        .onChange(of: viewModel.humidity) { _ in computeData() }
        .onChange(of: viewModel.pressure) { _ in computeData() }
        .onChange(of: viewModel.co2) { _ in computeData() }
        .onChange(of: timeUpdateTrigger) { _ in updateTimeText() }
    }

    private func computeData() {
        prominentValueCache = computeProminentValue()
        indicatorsCache = computeIndicators()
    }

    private func updateTimeText() {
        updatedAtText = viewModel.date?.ruuviAgo() ?? RuuviLocalization.Cards.UpdatedLabel.NoData.message
    }

    private func computeProminentValue() -> ProminentValueData {
        if (viewModel.version == 224 || viewModel.version == 240),
           let measurementService = measurementService {
            let (currentAirQIndex, maximumAirQIndex, currentAirQState) = measurementService.aqiString(
                for: viewModel.co2,
                pm25: viewModel.pm2_5,
                voc: viewModel.voc,
                nox: viewModel.nox
            )
            return ProminentValueData(
                value: currentAirQIndex.stringValue,
                superscriptValue: "/\(maximumAirQIndex.stringValue)",
                subscriptValue: RuuviLocalization.airQuality,
                showProgress: true,
                progressColor: Color(currentAirQState.color),
                progress: Float(currentAirQIndex) / Float(maximumAirQIndex)
            )
        } else {
            let tempString = measurementService?.stringWithoutSign(for: viewModel.temperature) ?? "N/A"
            return ProminentValueData(
                value: tempString,
                superscriptValue: "°C",
                subscriptValue: "Temperature",
                showProgress: false,
                progressColor: nil,
                progress: 0
            )
        }
    }

    private func computeIndicators() -> [IndicatorData] {
        var indicators: [IndicatorData] = []

        if viewModel.version == 224 || viewModel.version == 240 {
            // E0 indicators
            // Temperature
            if let temperature = viewModel.temperature {
                let tempValue = measurementService?.stringWithoutSign(for: temperature)
                indicators.append(
                    IndicatorData(
                        value: tempValue,
                        unit: measurementService?.units.temperatureUnit.symbol,
                        highlight: false
                    )
                )
            }

            // Humidity
            if let humidity = viewModel.humidity, let measurementService = measurementService {
                let humidityValue = measurementService.stringWithoutSign(
                    for: humidity,
                    temperature: viewModel.temperature
                )
                let humidityUnit = measurementService.units.humidityUnit
                let unit = humidityUnit == .dew
                    ? measurementService.units.temperatureUnit.symbol
                    : humidityUnit.symbol

                indicators.append(
                    IndicatorData(
                        value: humidityValue,
                        unit: unit,
                        highlight: false
                    )
                )
            }

            // Pressure
            if let pressure = viewModel.pressure {
                let pressureValue = measurementService?.stringWithoutSign(for: pressure)
                indicators.append(
                    IndicatorData(
                        value: pressureValue,
                        unit: measurementService?.units.pressureUnit.symbol,
                        highlight: false
                    )
                )
            }

            // CO2
            if let co2 = viewModel.co2,
               let co2Value = measurementService?.co2String(for: co2) {
                indicators.append(
                    IndicatorData(
                        value: co2Value,
                        unit: RuuviLocalization.unitCo2,
                        highlight: false
                    )
                )
            }

            // PM2.5
            if let pm25 = viewModel.pm2_5,
               let pm25Value = measurementService?.pm25String(for: pm25) {
                indicators.append(
                    IndicatorData(
                        value: pm25Value,
                        unit: "\(RuuviLocalization.pm25) \(RuuviLocalization.unitPm25)",
                        highlight: false
                    )
                )
            }

        } else {
            // V5 or older indicators
            // Humidity
            if let humidity = viewModel.humidity, let measurementService = measurementService {
                let humidityValue = measurementService.stringWithoutSign(
                    for: humidity,
                    temperature: viewModel.temperature
                )
                let humidityUnit = measurementService.units.humidityUnit
                let unit = humidityUnit == .dew
                    ? measurementService.units.temperatureUnit.symbol
                    : humidityUnit.symbol

                indicators.append(
                    IndicatorData(
                        value: humidityValue,
                        unit: unit,
                        highlight: false
                    )
                )
            }

            // Pressure
            if let pressure = viewModel.pressure {
                let pressureValue = measurementService?.stringWithoutSign(for: pressure)
                indicators.append(
                    IndicatorData(
                        value: pressureValue,
                        unit: measurementService?.units.pressureUnit.symbol,
                        highlight: false
                    )
                )
            }

            // Movement
            if let movement = viewModel.movementCounter {
                indicators.append(
                    IndicatorData(
                        value: "\(movement)",
                        unit: RuuviLocalization.Cards.Movements.title,
                        highlight: false
                    )
                )
            }
        }

        return indicators
    }
}

// MARK: - Data Models
struct ProminentValueData {
    let value: String?
    let superscriptValue: String?
    let subscriptValue: String?
    let showProgress: Bool
    let progressColor: Color?
    let progress: Float
}

struct IndicatorData: Identifiable {
    let id = UUID()
    let value: String?
    let unit: String?
    let highlight: Bool
}

// MARK: - Card Components
struct CardHeaderView: View {
    let viewModel: CardsViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(viewModel.name)
                .lineLimit(2)
                .font(.custom("Montserrat-Bold", size: 14))
                .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let alertIcon = getAlertIcon(for: viewModel.alertState) {
                Image(uiImage: alertIcon)
                    .renderingMode(.template)
                    .foregroundColor(getAlertTintColor(for: viewModel.alertState))
            }

            CardMenuView()
        }
        .padding(.top, 8)
        .padding(.leading, 8)
        .padding(.trailing, 0)
    }

    private func getAlertIcon(for alertState: AlertState?) -> UIImage? {
        guard let state = alertState else { return nil }
        switch state {
        case .empty: return nil
        case .registered: return RuuviAsset.iconAlertOn.image
        case .firing: return RuuviAsset.iconAlertActive.image
        }
    }

    private func getAlertTintColor(for alertState: AlertState?) -> Color {
        guard let state = alertState else { return .clear }
        switch state {
        case .empty: return .clear
        case .registered: return Color(RuuviColor.logoTintColor.color)
        case .firing: return Color(RuuviColor.orangeColor.color)
        }
    }
}

struct CardMenuView: View {
    var body: some View {
        Menu {
            Button("Choose Country") {
                print("Change country setting")
            }

            Button("Detect Location") {
                print("Enable geolocation")
            }
        } label: {
            Image(uiImage: RuuviAsset.more3dot.image)
                .renderingMode(.template)
                .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
                .frame(width: 36, height: 36)
        }
        .padding(.top, -4)
    }
}

struct ProminentValueView: View {
    let data: ProminentValueData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Text(data.value ?? "")
                    .font(.custom("Oswald-Bold", size: 30))
                    .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))

                VStack(alignment: .leading, spacing: -2) {
                    Spacer()

                    Text(data.superscriptValue ?? "")
                        .font(.custom("Oswald-Regular", size: 12))
                        .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))

                    Text(data.subscriptValue ?? "")
                        .font(.custom("Muli-Bold", size: 12))
                        .foregroundColor(
                            Color(RuuviColor.dashboardIndicator.color).opacity(0.6)
                        )

                    Spacer()
                }
            }

            if data.showProgress {
                ProgressView(value: data.progress)
                    .progressViewStyle(
                        LinearProgressViewStyle(tint: data.progressColor ?? .primary)
                    )
                    .frame(width: 120, height: 4)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.top, -24)
    }
}

struct IndicatorGridView: View {
    let indicators: [IndicatorData]

    private var columns: [GridItem] {
        indicators.count <= 2
            ? [GridItem(.flexible(), spacing: 8)]
            : [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(indicators) { indicator in
                IndicatorView(data: indicator)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, -6)
    }
}

struct IndicatorView: View {
    let data: IndicatorData

    private var textColor: Color {
        data.highlight
            ? Color(RuuviColor.orangeColor.color)
            : Color(RuuviColor.dashboardIndicator.color)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(data.value ?? "")
                .font(.custom("Montserrat-Bold", size: 14))
                .foregroundColor(textColor)
                .lineLimit(nil)

            Text(data.unit ?? "")
                .font(.custom("Muli-Regular", size: 12))
                .foregroundColor(textColor)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardFooterView: View {
    let viewModel: CardsViewModel
    let updatedAtText: String

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if let dataSourceIcon = getDataSourceIcon(for: viewModel.source) {
                Image(uiImage: dataSourceIcon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(
                        Color(RuuviColor.dashboardIndicator.color.withAlphaComponent(0.8))
                    )
                    .frame(width: 22, height: 22)
            }

            Text(updatedAtText)
                .font(.custom("Muli-Regular", size: 10))
                .foregroundColor(
                    Color(RuuviColor.dashboardIndicator.color.withAlphaComponent(0.8))
                )
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func getDataSourceIcon(for source: RuuviTagSensorRecordSource?) -> UIImage? {
        guard let source = source else { return nil }
        switch source {
        case .unknown: return nil
        case .advertisement, .bgAdvertisement: return RuuviAsset.iconBluetooth.image
        case .heartbeat, .log: return RuuviAsset.iconBluetoothConnected.image
        case .ruuviNetwork: return RuuviAsset.iconGateway.image
        }
    }
}

// MARK: - Extensions
extension UIColor {
    func toColor() -> Color {
        Color(self)
    }
}
