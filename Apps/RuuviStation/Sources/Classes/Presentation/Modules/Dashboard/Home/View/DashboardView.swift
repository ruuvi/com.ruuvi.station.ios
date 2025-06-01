import SwiftUI
import RuuviLocalization
import RuuviOntology
import RuuviService
import SwiftUIMasonry

struct CustomRefreshableScrollView<Content: View>: UIViewRepresentable {
    @Binding var isRefreshing: Bool
    let content: Content
    @State private var contentHeight: CGFloat = 0

    init(isRefreshing: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isRefreshing = isRefreshing
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        context.coordinator.hostingController = hostingController
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if isRefreshing {
            uiView.refreshControl?.beginRefreshing()
        } else {
            uiView.refreshControl?.endRefreshing()
        }

        if let hostingView = context.coordinator.hostingController?.view {
            hostingView.frame.size.height = contentHeight
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isRefreshing: $isRefreshing)
    }

    class Coordinator: NSObject {
        @Binding var isRefreshing: Bool
        var hostingController: UIHostingController<Content>?

        init(isRefreshing: Binding<Bool>) {
            self._isRefreshing = isRefreshing
        }

        @objc func handleRefresh() {
            isRefreshing = true
        }
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DashboardView: View {
    @EnvironmentObject var state: DashboardViewState
    @GestureState private var isScrolling = false
    let measurementService: RuuviServiceMeasurement
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var isRefreshing = false
    @State private var draggedItem: CardsViewModel?

    private func refreshData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("ekhane...")
            isRefreshing = false
        }
    }

    private func calculateColumns(for width: CGFloat) -> Int {
        let cardMinWidth: CGFloat = 300
        let spacing: CGFloat = 8
        let padding: CGFloat = 16

        let availableWidth = width - (padding * 2)
        let maxColumns = max(1, Int(availableWidth / (cardMinWidth + spacing)))

        // Apply device-specific logic
        if UIDevice.current.userInterfaceIdiom == .pad {
            return min(maxColumns, horizontalSizeClass == .regular ? 3 : 2)
        } else {
            return min(maxColumns, verticalSizeClass == .compact ? 2 : 1)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VMasonry(columns: calculateColumns(for: geometry.size.width), spacing: 0) {
                    ForEach(state.items, id: \.id) { viewModel in
                        DashboardViewRowSwiftUI(
                            viewModel: viewModel,
                            measurementService: measurementService
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
            }
        }
    }
}

/// DropDelegate that reorders the array `items` when the user drags
/// one card onto another. This delegate is attached to each item in the layout.
struct CardDropDelegate: DropDelegate {
    /// The item into whose "space" we’re dropping
    let targetItem: CardsViewModel

    /// A binding to the entire items array so we can reorder it
    @Binding var items: [CardsViewModel]

    /// A binding that stores the currently dragged item
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

        // Reorder as user drags over a new target
        if fromIndex != toIndex {
            withAnimation {
                items.move(
                    fromOffsets: IndexSet(integer: fromIndex),
                    toOffset: (fromIndex < toIndex) ? toIndex+1 : toIndex
                )
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

struct CardsBackgroundViewWrapper: UIViewRepresentable {
    var backgroundImage: UIImage?
    var withAnimation: Bool = true

    func makeUIView(context: Context) -> CardsBackgroundView {
        let view = CardsBackgroundView()
        return view
    }

    func updateUIView(_ uiView: CardsBackgroundView, context: Context) {
        uiView.setBackgroundImage(with: backgroundImage, withAnimation: withAnimation)
    }
}

struct DashboardIndicatorViewSwiftUIView: View {
    // Properties for the value and unit
    let value: String?
    let unit: String?

    // Property to handle highlight state
    let highlight: Bool

    // Colors
    private var valueColor: Color {
        highlight ? Color(RuuviColor.orangeColor.color) : Color(RuuviColor.dashboardIndicator.color)
    }

    private var unitColor: Color {
        highlight ? Color(RuuviColor.orangeColor.color) : Color(RuuviColor.dashboardIndicator.color)
    }

    var body: some View {
        HStack(spacing: 4) {
            // Value Label
            Text(value ?? "")
                .font(.custom("Montserrat-Bold", size: 14))
                .foregroundColor(valueColor)
                .lineLimit(nil)

            // Unit Label
            Text(unit ?? "")
                .font(.custom("Muli-Regular", size: 12))
                .foregroundColor(unitColor)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DashboardIndicatorProminentViewSwiftUIView: View {
    // Properties
    let value: String?
    let superscriptValue: String?
    let subscriptValue: String?
    let showProgress: Bool
    let progressColor: Color?

    // For progress value (converting to percentage)
    private var progress: Float {
        Float(value?.intValue ?? 0) / 100
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Value and superscript/subscript container
                HStack(alignment: .center, spacing: 6) {
                    // Main Value
                    Text(value ?? "")
                        .font(.custom("Oswald-Bold", size: 30))
                        .foregroundColor(
                            RuuviColor.dashboardIndicatorBig.color.toColor()
                        )

                    VStack(alignment: .leading, spacing: -2) {
                        Spacer()
                        // Superscript
                        Text(superscriptValue ?? "")
                            .font(.custom("Oswald-Regular", size: 12))
                            .foregroundColor(
                                RuuviColor.dashboardIndicatorBig.color.toColor()
                            )

                        // Subscript
                        Text(subscriptValue ?? "")
                            .font(.custom("Muli-Bold", size: 12))
                            .foregroundColor(
                                RuuviColor.dashboardIndicator.color
                                    .toColor()
                                    .opacity(0.6)
                            )
                        Spacer()
                    }
                }

                // Progress View
                if showProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(
                            LinearProgressViewStyle(tint: progressColor ?? .primary)
                        )
                        .frame(width: 120, height: 4)
                        .padding(.bottom, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

    }
}

// swiftlint:disable:next type_body_length
struct DashboardViewRowSwiftUI: View {
    @EnvironmentObject var state: DashboardViewState
    @ObservedObject var viewModel: CardsViewModel
    var measurementService: RuuviServiceMeasurement?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(RuuviColor.dashboardCardBG.color.toColor())

            HStack {
                if state.dashboardViewType == .image,
                   let background = viewModel.background {
                    CardsBackgroundViewWrapper(backgroundImage: background)
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: 110
                        )
                        .clipped()
                        .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(viewModel.name)
                            .lineLimit(2)
                            .font(.custom("Montserrat-Bold", size: 14))
                            .foregroundColor(RuuviColor.dashboardIndicatorBig.color.toColor())
                            .frame(maxWidth: .infinity, alignment: .leading)


                        // Alert icon
                        if let alertIconName = alertIconName() {
                            Image(uiImage: alertIconName)
                                .renderingMode(.template)
                                .foregroundColor(alertIconTintColor())
                        }

                        // More action
                        Menu {
                            Button {
                                print("Change country setting")
                            } label: {
                                Label("Choose Country", systemImage: "globe")
                            }

                            Button {
                                print("Enable geolocation")
                            } label: {
                                Label("Detect Location", systemImage: "location.circle")
                            }
                        } label: {
                            ZStack {
                                Image(uiImage: RuuviAsset.more3dot.image)
                                    .renderingMode(.template)
                                    .foregroundColor(RuuviColor.dashboardIndicatorBig.color.toColor())
                            }
                            .frame(width: 36, height: 36)
                        }
                        .padding(.top, -4)
                    }
                    .padding(.top, 8)
                    .padding(.leading, 8)
                    .padding(.trailing, 0)

                    DashboardIndicatorProminentViewSwiftUIView(
                        value: computeProminentValue().value,
                        superscriptValue: computeProminentValue().superscriptValue,
                        subscriptValue: computeProminentValue().subscriptValue,
                        showProgress: computeProminentValue().showProgress,
                        progressColor: computeProminentValue().progressColor?
                            .toColor()
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, -24)

                    buildIndicatorGrid()
                        .padding(.horizontal, 8)
                        .padding(.vertical, -6)

                    // The row with data source icon + updatedAt + battery
                    HStack(alignment: .center, spacing: 4) {
                        // For a dataSource icon if needed:
                        if let dataSourceIcon = dataSourceIcon() {
                            Image(uiImage: dataSourceIcon)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(RuuviColor
                                    .dashboardIndicator.color
                                    .withAlphaComponent(0.8)
                                    .toColor())
                                .frame(width: 22, height: 22)
                        }

                        // updatedAt text
                        UpdatedAtTextView(date: viewModel.date)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            }


        }
    }

    // MARK: - Helpers for the "Prominent" row
    // swiftlint:disable:next large_tuple
    private func computeProminentValue() -> (
        value: String?,
        superscriptValue: String?,
        subscriptValue: String?,
        showProgress: Bool,
        progressColor: UIColor?
    ) {

        if (viewModel.version == 224 || viewModel.version == 240),
           let (
               currentAirQIndex,
               maximumAirQIndex,
               currentAirQState
           ) = measurementService?.aqiString(
               for: viewModel.co2,
               pm25: viewModel.pm2_5,
               voc: viewModel.voc,
               nox: viewModel.nox
           ) {
            return (
                currentAirQIndex.stringValue,
                "/\(maximumAirQIndex.stringValue)",
                RuuviLocalization.airQuality,
                true,
                currentAirQState.color
            )
        } else {
            // Example: temperature
            let tempString = measurementService?.stringWithoutSign(for: viewModel.temperature) ?? "N/A"
            return (tempString, "°C", "Temperature", false, nil)
        }
    }

    // MARK: - Helpers for the additional Indicator Grid
    @ViewBuilder
    private func buildIndicatorGrid() -> some View {
        let indicatorsE0: [DashboardIndicatorViewSwiftUIView] = indicatorsForE0(
            viewModel,
            measurementService: measurementService
        )

        let indicatorsV5OrOlder: [DashboardIndicatorViewSwiftUIView] = indicatorsForV5OrOlder(
            viewModel,
            measurementService: measurementService
        )

        if viewModel.version == 224 || viewModel.version == 240 {
            DashboardGridView(indicators: indicatorsE0)
        } else {
            DashboardGridView(indicators: indicatorsV5OrOlder)
        }
    }

    struct DashboardGridView: View {
        let indicators: [DashboardIndicatorViewSwiftUIView]

        private let singleColumn = [
            GridItem(.flexible(), spacing: 8)
        ]

        private let multipleColumns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]

        var body: some View {
            if indicators.indices.count <= 2 {
                LazyVGrid(columns: singleColumn, spacing: 4) {
                    ForEach(indicators.indices, id: \.self) { index in
                        indicators[index]
                    }
                }
            } else {
                LazyVGrid(columns: multipleColumns, spacing: 4) {
                    ForEach(indicators.indices, id: \.self) { index in
                        indicators[index]
                    }
                }
            }
        }
    }

    private func indicatorsForV5OrOlder(
        _ viewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) -> [DashboardIndicatorViewSwiftUIView] {
        var indicators: [DashboardIndicatorViewSwiftUIView] = []

        // Humidity
        if let humidity = viewModel.humidity,
           let measurementService {
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: viewModel.temperature
            )
            let humidityUnit = measurementService.units.humidityUnit
            let unit = humidityUnit == .dew
                ? measurementService.units.temperatureUnit.symbol
                : humidityUnit.symbol
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
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
                DashboardIndicatorViewSwiftUIView(
                    value: pressureValue,
                    unit: measurementService?.units.pressureUnit.symbol,
                    highlight: false
                )
            )
        }

        // Movement
        if let movement = viewModel.movementCounter {
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
                    value: "\(movement)",
                    unit: RuuviLocalization.Cards.Movements.title,
                    highlight: false
                )
            )
        }

        return indicators
    }

    // swiftlint:disable:next function_body_length
    private func indicatorsForE0(
        _ viewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) -> [DashboardIndicatorViewSwiftUIView] {
        var indicators: [DashboardIndicatorViewSwiftUIView] = []

        // Temperature
        if let temperature = viewModel.temperature {
            let tempValue = measurementService?.stringWithoutSign(for: temperature)
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
                    value: tempValue,
                    unit: measurementService?.units.temperatureUnit.symbol,
                    highlight: false
                )
            )
        }

        // Humidity
        if let humidity = viewModel.humidity,
           let measurementService {
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: viewModel.temperature
            )
            let humidityUnit = measurementService.units.humidityUnit
            let unit = humidityUnit == .dew
                ? measurementService.units.temperatureUnit.symbol
                : humidityUnit.symbol
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
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
                DashboardIndicatorViewSwiftUIView(
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
                DashboardIndicatorViewSwiftUIView(
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
                DashboardIndicatorViewSwiftUIView(
                    value: pm25Value,
                    unit: "\(RuuviLocalization.pm25) \(RuuviLocalization.unitPm25)",
                    highlight: false
                )
            )
        }

        // PM10
        if let pm10 = viewModel.pm10,
           let pm10Value = measurementService?.pm10String(for: pm10) {
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
                    value: pm10Value,
                    unit: "\(RuuviLocalization.pm10) \(RuuviLocalization.unitPm10)",
                    highlight: false
                )
            )
        }

        // NOx
        if let nox = viewModel.nox,
           let noxValue = measurementService?.noxString(for: nox) {
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
                    value: noxValue,
                    unit: RuuviLocalization.unitNox,
                    highlight: false
                )
            )
        }

        // VOC
        if let voc = viewModel.voc,
           let vocValue = measurementService?.vocString(for: voc) {
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
                    value: vocValue,
                    unit: RuuviLocalization.unitVoc,
                    highlight: false
                )
            )
        }

        // Luminosity
        if let luminosity = viewModel.luminance,
           let luminosityValue = measurementService?.luminosityString(for: luminosity) {
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
                    value: luminosityValue,
                    unit: RuuviLocalization.unitLuminosity,
                    highlight: false
                )
            )
        }

        // Sound
        if let sound = viewModel.dbaAvg,
           let soundValue = measurementService?.soundAvgString(for: sound) {
            indicators.append(
                DashboardIndicatorViewSwiftUIView(
                    value: soundValue,
                    unit: RuuviLocalization.unitSound,
                    highlight: false
                )
            )
        }

        return indicators
    }

    // MARK: - Data Source icon
    private func dataSourceIcon() -> UIImage? {
        // Similar logic to your original code:
        guard let source = viewModel.source else { return nil }
        switch source {
        case .unknown: return nil
        case .advertisement, .bgAdvertisement: return RuuviAsset.iconBluetooth.image
        case .heartbeat, .log: return RuuviAsset.iconBluetoothConnected.image
        case .ruuviNetwork: return RuuviAsset.iconGateway.image
        }
    }

    // MARK: - UpdatedAt text
    private func updatedAtText() -> String? {
        // Mirror your original "date?.ruuviAgo()" logic
        if let date = viewModel.date {
            return date.ruuviAgo()
        } else {
            return RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }
    }

    // MARK: - Alert icon name
    private func alertIconName() -> UIImage? {
        // Simplified example: show a single icon if "alert" is active
        guard let state = viewModel.alertState else { return nil }
        switch state {
        case .empty: return nil
        case .registered: return RuuviAsset.iconAlertOn.image
        case .firing: return RuuviAsset.iconAlertActive.image
        }
    }

    // Possibly set tint color for alert:
    private func alertIconTintColor() -> Color {
        guard let state = viewModel.alertState else { return .clear }
        switch state {
        case .empty: return .clear
        case .registered: return RuuviColor.logoTintColor.color.toColor()
        case .firing: return RuuviColor.orangeColor.color.toColor()
        }
    }

    // MARK: - Separate View for UpdatedAt Text
    struct UpdatedAtTextView: View {
        let date: Date?
        @State private var updatedText: String = ""

        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        var body: some View {
            Text(updatedText)
                .font(.custom("Muli-Regular", size: 10))
                .foregroundColor(RuuviColor
                    .dashboardIndicator.color
                    .withAlphaComponent(0.8)
                    .toColor())
                .onAppear(perform: updateText)
                .onReceive(timer) { _ in
                    updateText()
                }
        }

        private func updateText() {
            if let date = date {
                updatedText = date.ruuviAgo() // Use your `ruuviAgo()` logic here
            } else {
                updatedText = RuuviLocalization.Cards.UpdatedLabel.NoData.message
            }
        }
    }
}

// MARK: - Convert UIColor to SwiftUI Color
extension UIColor {
    func toColor() -> Color {
        Color(self)
    }
}
