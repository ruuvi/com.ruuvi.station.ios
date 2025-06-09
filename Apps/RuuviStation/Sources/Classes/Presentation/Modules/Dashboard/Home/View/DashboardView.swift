import SwiftUI
import RuuviLocalization
import RuuviOntology
import RuuviService
import SwiftUIMasonry

struct DashboardView: View {
    @EnvironmentObject var state: DashboardViewState
    @EnvironmentObject var actions: DashboardViewActions
    @GestureState private var isScrolling = false

    let measurementService: RuuviServiceMeasurement

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // Global timer for time updates
    @State private var timeUpdateTrigger = UUID()
    private let updateTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Cache the calculated columns to prevent repeated calculations
    @State private var cachedColumns: Int = 1
    @State private var lastKnownWidth: CGFloat = 0
    @State private var draggedItem: CardsViewModel?

    // UI State
    @State private var showingBluetoothAlert = false
    @State private var bluetoothUserDeclined = false
    @State private var showingKeepConnectionDialog = false
    @State private var keepConnectionViewModel: CardsViewModel?
    @State private var keepConnectionType: KeepConnectionType = .chart

    private func calculateColumns(
        for width: CGFloat,
        verticalSizeClass: UserInterfaceSizeClass?,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Int {
        let cardMinWidth: CGFloat = 300
        let spacing: CGFloat = 8
        let padding: CGFloat = 16

        let availableWidth = width - (padding * 2)
        let maxColumns = max(1, Int(availableWidth / (cardMinWidth + spacing)))

        if UIDevice.current.userInterfaceIdiom == .pad {
            return min(maxColumns, horizontalSizeClass == .regular ? 3 : 2)
        } else {
            return verticalSizeClass == .regular ? 1 : 2
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if state.showNoSensorsMessage {
                    EmptyView()
                       .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VMasonry(
                        columns: cachedColumns,
                        spacing: 0
                    ) {
                        ForEach(state.items, id: \.id) { viewModel in
                            Group {
                                if state.dashboardViewType == .image {
                                    DashboardImageCardView(
                                        viewModel: viewModel,
                                        measurementService: measurementService,
                                        timeUpdateTrigger: timeUpdateTrigger
                                    )
                                } else {
                                    DashboardPlainCardView(
                                        viewModel: viewModel,
                                        measurementService: measurementService,
                                        timeUpdateTrigger: timeUpdateTrigger
                                    )
                                }
                            }
                            .contextMenu {
                                CardContextMenu(viewModel: viewModel)
                            }
                            .onTapGesture {
                                actions.cardDidTap.send(viewModel)
                            }
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
                                    items: Binding(
                                        get: { state.items },
                                        set: { newItems in
                                            state.updateItems(newItems)
                                        }
                                    ),
                                    draggedItem: $draggedItem,
                                    onReorder: { reorderedItems in
                                        actions.cardDidReorder.send(reorderedItems)
                                    }
                                )
                            )
                            .padding(4)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: state.items)
                    .animation(.easeInOut(duration: 0.3), value: cachedColumns)
                    .animation(.easeInOut(duration: 0.3), value: state.dashboardViewType)
                }
            }
           .refreshable {
               onPullToRefresh()
           }
            .onReceive(updateTimer) { _ in
                timeUpdateTrigger = UUID()
            }
            .onChange(of: geometry.size.width) { newWidth in
                if abs(newWidth - lastKnownWidth) > 1 {
                    let newColumns = calculateColumns(
                        for: newWidth,
                        verticalSizeClass: verticalSizeClass,
                        horizontalSizeClass: horizontalSizeClass
                    )
                    if newColumns != cachedColumns {
                        cachedColumns = newColumns
                    }
                    lastKnownWidth = newWidth
                }
            }
            .onChange(of: verticalSizeClass) { newValue in
                let newColumns = calculateColumns(
                    for: geometry.size.width,
                    verticalSizeClass: newValue,
                    horizontalSizeClass: horizontalSizeClass
                )
                if newColumns != cachedColumns {
                    cachedColumns = newColumns
                }
            }
            .onChange(of: horizontalSizeClass) { newValue in
                let newColumns = calculateColumns(
                    for: geometry.size.width,
                    verticalSizeClass: verticalSizeClass,
                    horizontalSizeClass: newValue
                )
                if newColumns != cachedColumns {
                    cachedColumns = newColumns
                }
            }
            .onAppear {
                cachedColumns = calculateColumns(
                    for: geometry.size.width,
                    verticalSizeClass: verticalSizeClass,
                    horizontalSizeClass: horizontalSizeClass
                )
                lastKnownWidth = geometry.size.width
                setupNotificationObservers()
            }
        }
       .alert("Bluetooth Disabled", isPresented: $showingBluetoothAlert) {
           Button("Settings") {
               if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                   UIApplication.shared.open(settingsUrl)
               }
           }
           Button("Cancel", role: .cancel) { }
       } message: {
           Text(bluetoothUserDeclined ?
                "Please enable Bluetooth permission in Settings to connect to sensors." :
                "Please turn on Bluetooth to connect to sensors.")
       }
       .alert("Keep Connection", isPresented: $showingKeepConnectionDialog) {
           Button("Keep Connected") {
               handleKeepConnectionConfirm()
           }
           Button("Not Now", role: .cancel) {
               handleKeepConnectionDismiss()
           }
       } message: {
           Text("Do you want to keep connection to this sensor to read data in background?")
       }
    }

    private func onPullToRefresh() {
        NotificationCenter.default.post(name: .dashboardPullToRefresh, object: nil)
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .showBluetoothDisabled,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let userDeclined = userInfo["userDeclined"] as? Bool {
                bluetoothUserDeclined = userDeclined
                showingBluetoothAlert = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: .showKeepConnectionDialogChart,
            object: nil,
            queue: .main
        ) { notification in
            if let viewModel = notification.object as? CardsViewModel {
                keepConnectionViewModel = viewModel
                keepConnectionType = .chart
                showingKeepConnectionDialog = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: .showKeepConnectionDialogSettings,
            object: nil,
            queue: .main
        ) { notification in
            if let viewModel = notification.object as? CardsViewModel {
                keepConnectionViewModel = viewModel
                keepConnectionType = .settings
                showingKeepConnectionDialog = true
            }
        }
    }

    private func handleKeepConnectionConfirm() {
        guard let viewModel = keepConnectionViewModel else { return }

        switch keepConnectionType {
        case .chart:
            NotificationCenter.default.post(
                name: .keepConnectionConfirmedChart,
                object: viewModel
            )
        case .settings:
            NotificationCenter.default.post(
                name: .keepConnectionConfirmedSettings,
                object: viewModel
            )
        }

        keepConnectionViewModel = nil
    }

    private func handleKeepConnectionDismiss() {
        guard let viewModel = keepConnectionViewModel else { return }

        switch keepConnectionType {
        case .chart:
            NotificationCenter.default.post(
                name: .keepConnectionDismissedChart,
                object: viewModel
            )
        case .settings:
            NotificationCenter.default.post(
                name: .keepConnectionDismissedSettings,
                object: viewModel
            )
        }

        keepConnectionViewModel = nil
    }
}

enum KeepConnectionType {
    case chart
    case settings
}

// Add these notification names to your extension
extension Notification.Name {
    static let keepConnectionConfirmedChart = Notification.Name("keepConnectionConfirmedChart")
    static let keepConnectionDismissedChart = Notification.Name("keepConnectionDismissedChart")
    static let keepConnectionConfirmedSettings = Notification.Name("keepConnectionConfirmedSettings")
    static let keepConnectionDismissedSettings = Notification.Name("keepConnectionDismissedSettings")
}

// MARK: - Dashboard Plain Card View (No Prominent View)
struct DashboardPlainCardView: View {
    @EnvironmentObject var state: DashboardViewState
    @ObservedObject var viewModel: CardsViewModel
    let measurementService: RuuviServiceMeasurement?
    let timeUpdateTrigger: UUID

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(RuuviColor.dashboardCardBG.color))

            VStack(alignment: .leading, spacing: 8) {
                // Header
                CardHeaderView(viewModel: viewModel)

                // Indicators Grid (no prominent view for plain cards)
                IndicatorGridView(
                    viewModel: viewModel,
                    measurementService: measurementService,
                    dashboardViewType: state.dashboardViewType
                )

                // Footer
                CardFooterView(
                    viewModel: viewModel,
                    timeUpdateTrigger: timeUpdateTrigger
                )
            }
        }
    }
}

// MARK: - Dashboard Image Card View (With Prominent View)
struct DashboardImageCardView: View {
    @EnvironmentObject var state: DashboardViewState
    @ObservedObject var viewModel: CardsViewModel
    let measurementService: RuuviServiceMeasurement?
    let timeUpdateTrigger: UUID

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(RuuviColor.dashboardCardBG.color))

            HStack(spacing: 0) {
                // Background Image (25% width like UIKit version)
                if let background = viewModel.background {
                    CardsBackgroundViewWrapper(backgroundImage: background)
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 100, maxWidth: 120)
                        .clipped()
                        .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                } else {
                    // Empty space when no background
                    Color.clear
                        .frame(width: 100)
                }
                
                // Content area (75% width)
                VStack(alignment: .leading, spacing: 4) {
                    // Header
                    CardHeaderView(viewModel: viewModel)

                    // Prominent View (only for image cards)
                    ProminentValueView(
                        viewModel: viewModel,
                        measurementService: measurementService
                    )

                    // Indicators Grid
                    IndicatorGridView(
                        viewModel: viewModel,
                        measurementService: measurementService,
                        dashboardViewType: state.dashboardViewType
                    )

                    // Footer
                    CardFooterView(
                        viewModel: viewModel,
                        timeUpdateTrigger: timeUpdateTrigger
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Card Components
struct CardHeaderView: View {
    @EnvironmentObject var state: DashboardViewState
    let viewModel: CardsViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(viewModel.name)
                .lineLimit(2)
                .font(.custom("Montserrat-Bold", size: 14))
                .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                .frame(maxWidth: .infinity, alignment: .leading)

            if let alertIcon = getAlertIcon(for: viewModel.alertState) {
                Image(uiImage: alertIcon)
                    .renderingMode(.template)
                    .foregroundColor(getAlertTintColor(for: viewModel.alertState))
                    .frame(width: 24, height: 18) // Fixed size to prevent layout issues
            }

            CardMenuView(
                viewModel: viewModel, 
                currentIndex: getCurrentIndex()
            )
        }
        .padding(.top, 8)
        .padding(.leading, 8)
        .padding(.trailing, 0)
    }
    
    private func getCurrentIndex() -> Int {
        return state.items.firstIndex(where: { $0.id == viewModel.id }) ?? 0
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
    @EnvironmentObject var actions: DashboardViewActions
    @EnvironmentObject var state: DashboardViewState
    let viewModel: CardsViewModel
    let currentIndex: Int
    
    var body: some View {
        Menu {
            Button(RuuviLocalization.fullImageView) {
                actions.cardDidTriggerOpenCardImageView.send(viewModel)
            }
            
            Button(RuuviLocalization.historyView) {
                actions.cardDidTriggerChart.send(viewModel)
            }
            
            Button(RuuviLocalization.settingsAndAlerts) {
                actions.cardDidTriggerSettings.send(viewModel)
            }
            
            Button(RuuviLocalization.changeBackground) {
                actions.cardDidTriggerChangeBackground.send(viewModel)
            }
            
            Button(RuuviLocalization.rename) {
                actions.cardDidTriggerRename.send(viewModel)
            }
            
            // Move actions only if there are multiple sensors
            if state.items.count > 1 {
                if currentIndex > 0 {
                    Button(RuuviLocalization.moveUp) {
                        actions.cardDidTriggerMoveUp.send(viewModel)
                    }
                }
                
                if currentIndex < state.items.count - 1 {
                    Button(RuuviLocalization.moveDown) {
                        actions.cardDidTriggerMoveDown.send(viewModel)
                    }
                }
            }
            
            if viewModel.canShareTag {
                Button(RuuviLocalization.TagSettings.shareButton) {
                    actions.cardDidTriggerShare.send(viewModel)
                }
            }
            
            Button(RuuviLocalization.remove) {
                actions.cardDidTriggerRemove.send(viewModel)
            }
        } label: {
            Image(uiImage: RuuviAsset.more3dot.image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))
                .frame(width: 16, height: 16)
                .clipped()
                .padding(4)
        }
    }
}

// MARK: - Card Context Menu
struct CardContextMenu: View {
    @EnvironmentObject var actions: DashboardViewActions
    @EnvironmentObject var state: DashboardViewState
    let viewModel: CardsViewModel
    
    var body: some View {
        let currentIndex = getCurrentIndex()
        
        Button(RuuviLocalization.fullImageView) {
            actions.cardDidTriggerOpenCardImageView.send(viewModel)
        }
        
        Button(RuuviLocalization.historyView) {
            actions.cardDidTriggerChart.send(viewModel)
        }
        
        Button(RuuviLocalization.settingsAndAlerts) {
            actions.cardDidTriggerSettings.send(viewModel)
        }
        
        Button(RuuviLocalization.changeBackground) {
            actions.cardDidTriggerChangeBackground.send(viewModel)
        }
        
        Button(RuuviLocalization.rename) {
            actions.cardDidTriggerRename.send(viewModel)
        }
        
        // Move actions only if there are multiple sensors
        if state.items.count > 1 {
            if currentIndex > 0 {
                Button(RuuviLocalization.moveUp) {
                    actions.cardDidTriggerMoveUp.send(viewModel)
                }
            }
            
            if currentIndex < state.items.count - 1 {
                Button(RuuviLocalization.moveDown) {
                    actions.cardDidTriggerMoveDown.send(viewModel)
                }
            }
        }
        
        if viewModel.canShareTag {
            Button(RuuviLocalization.TagSettings.shareButton) {
                actions.cardDidTriggerShare.send(viewModel)
            }
        }
        
        Button(RuuviLocalization.remove, role: .destructive) {
            actions.cardDidTriggerRemove.send(viewModel)
        }
    }
    
    private func getCurrentIndex() -> Int {
        return state.items.firstIndex(where: { $0.id == viewModel.id }) ?? 0
    }
}

// MARK: - Prominent Value View (Only for Image Cards)
struct ProminentValueView: View {
    let viewModel: CardsViewModel
    let measurementService: RuuviServiceMeasurement?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Text(prominentData.value)
                    .font(.custom("Oswald-Bold", size: 30))
                    .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))

                VStack(alignment: .leading, spacing: -2) {
                    Spacer()

                    Text(prominentData.superscriptValue)
                        .font(.custom("Oswald-Regular", size: 12))
                        .foregroundColor(Color(RuuviColor.dashboardIndicatorBig.color))

                    Text(prominentData.subscriptValue)
                        .font(.custom("Muli-Bold", size: 12))
                        .foregroundColor(
                            Color(RuuviColor.dashboardIndicator.color).opacity(0.6)
                        )

                    Spacer()
                }
            }

            if prominentData.showProgress {
                ProgressView(value: prominentData.progress)
                    .progressViewStyle(
                        LinearProgressViewStyle(
                            tint: prominentData.progressColor ?? .accentColor
                        )
                    )
                    .frame(width: 120, height: 4)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var prominentData: ProminentData {
        guard let version = viewModel.version else {
            return getTemperatureProminentData()
        }

        let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(from: version)
        if firmwareVersion == .e0 || firmwareVersion == .f0 {
            // Air Quality Index for E0/F0 in image view
            if let (currentAirQIndex, maximumAirQIndex, currentAirQState) = measurementService?.aqiString(
                for: viewModel.co2,
                pm25: viewModel.pm2_5,
                voc: viewModel.voc,
                nox: viewModel.nox
            ) {
                return ProminentData(
                    value: currentAirQIndex.stringValue,
                    superscriptValue: "/\(maximumAirQIndex.stringValue)",
                    subscriptValue: RuuviLocalization.airQuality,
                    showProgress: true,
                    progressColor: Color(currentAirQState.color),
                    progress: Float(currentAirQIndex) / Float(maximumAirQIndex)
                )
            }
        }

        // Temperature for V5 or fallback
        return getTemperatureProminentData()
    }

    private func getTemperatureProminentData() -> ProminentData {
        var temperatureValue: String
        var temperatureUnit: String

        if let temp = measurementService?.stringWithoutSign(for: viewModel.temperature) {
            temperatureValue = temp.components(separatedBy: String.nbsp).first ?? "N/A"
        } else {
            temperatureValue = RuuviLocalization.na
        }

        if let unit = measurementService?.units.temperatureUnit {
            temperatureUnit = unit.symbol
        } else {
            temperatureUnit = RuuviLocalization.na
        }

        return ProminentData(
            value: temperatureValue,
            superscriptValue: temperatureUnit,
            subscriptValue: " ",
            showProgress: false,
            progressColor: nil,
            progress: 0
        )
    }
}

// MARK: - Indicator Grid View
struct IndicatorGridView: View {
    let viewModel: CardsViewModel
    let measurementService: RuuviServiceMeasurement?
    let dashboardViewType: DashboardType

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 4) {
            ForEach(indicators, id: \.id) { indicator in
                IndicatorView(data: indicator)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, -6)
    }

    private var gridColumns: [GridItem] {
        indicators.count < 3
            ? [GridItem(.flexible(), spacing: 8)]
            : [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    private var indicators: [IndicatorData] {
        guard let version = viewModel.version else { return [] }

        let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(from: version)
        if firmwareVersion == .e0 || firmwareVersion == .f0 {
            return getE0Indicators()
        } else {
            return getV5OrOlderIndicators()
        }
    }

    private func getV5OrOlderIndicators() -> [IndicatorData] {
        var indicators: [IndicatorData] = []

        // Temperature (only for simple view, not for image view since it's prominent)
        if dashboardViewType == .simple, let temperature = viewModel.temperature {
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

        return indicators
    }

    // swiftlint:disable:next function_body_length
    private func getE0Indicators() -> [IndicatorData] {
        var indicators: [IndicatorData] = []

        // AQI for simple view (since there's no prominent view), skip for image view (since it's prominent)
        if dashboardViewType == .simple, let (
               currentAirQIndex,
               maximumAirQIndex,
               _
           ) = measurementService?.aqiString(
               for: viewModel.co2,
               pm25: viewModel.pm2_5,
               voc: viewModel.voc,
               nox: viewModel.nox
           ) {
            indicators.append(
                IndicatorData(
                    value: currentAirQIndex.stringValue + "/\(maximumAirQIndex.stringValue)",
                    unit: RuuviLocalization.airQuality,
                    highlight: false
                )
            )
        }

        // Temperature (always shown for E0/F0 since it's not prominent for E0/F0)
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

        // PM10
        if let pm10 = viewModel.pm10,
           let pm10Value = measurementService?.pm10String(for: pm10) {
            indicators.append(
                IndicatorData(
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
                IndicatorData(
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
                IndicatorData(
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
                IndicatorData(
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
                IndicatorData(
                    value: soundValue,
                    unit: RuuviLocalization.unitSound,
                    highlight: false
                )
            )
        }

        return indicators
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

// MARK: - Card Footer View with Fixed Timer
struct CardFooterView: View {
    let viewModel: CardsViewModel
    let timeUpdateTrigger: UUID

    @State private var updatedAtText: String = ""

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
        .onAppear {
            updateTimeText()
        }
        .onChange(of: timeUpdateTrigger) { _ in
            updateTimeText()
        }
        .onChange(of: viewModel.date) { _ in
            updateTimeText()
        }
    }

    private func updateTimeText() {
        if let date = viewModel.date {
            updatedAtText = date.ruuviAgo()
        } else {
            updatedAtText = RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }
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

// MARK: - Data Models
struct ProminentData {
    let value: String
    let superscriptValue: String
    let subscriptValue: String
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

// MARK: - Card Drop Delegate
struct CardDropDelegate: DropDelegate {
    let targetItem: CardsViewModel
    @Binding var items: [CardsViewModel]
    @Binding var draggedItem: CardsViewModel?
    let onReorder: ([CardsViewModel]) -> Void

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
        // Trigger reorder callback with updated items
        onReorder(items)
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

// MARK: - Extensions
extension UIColor {
    func toColor() -> Color {
        Color(self)
    }
}
