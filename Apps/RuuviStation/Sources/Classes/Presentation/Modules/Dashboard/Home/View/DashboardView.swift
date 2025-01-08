import SwiftUI
import RuuviLocalization

struct DashboardView: View {
    @EnvironmentObject var state: DashboardViewState
    @GestureState private var isScrolling = false
    let measurementService: RuuviServiceMeasurement

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(state.items, id: \.id) { viewModel in
                            DashboardViewRowSwiftUI(
                                viewModel: viewModel,
                                measurementService: measurementService
                            )
                            .id(viewModel.id)
                        }
                    }
                }
//                .scrollPosition(id: $state.scrollManager.currentPosition)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isScrolling) { _, state, _ in
                            state = true
                            self.state.scrollManager.updateScrolling(true)
                        }
                        .onEnded { _ in
                            self.state.scrollManager.updateScrolling(false)
                        }
                )
                .onChange(of: state.scrollManager.currentPosition) { position in
                    if let position = position {
                        withAnimation {
                            proxy.scrollTo(position, anchor: .center)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

import SwiftUI
import RuuviOntology
import RuuviService

/// 1) A small UIViewRepresentable wrapper around your DashboardIndicatorView.
struct DashboardIndicatorRepresentable: UIViewRepresentable {
    /// You might inject a pre-configured DashboardIndicatorView
    /// or create it dynamically; here's a minimal example:
    let indicatorView = DashboardIndicatorView()

    /// Optionally store some text/values to set on the indicator.
    let value: String?
    let unit: String?

    func makeUIView(context: Context) -> DashboardIndicatorView {
        indicatorView
    }

    func updateUIView(_ uiView: DashboardIndicatorView, context: Context) {
        uiView.setValue(with: value, unit: unit)
    }
}

/// 2) A small UIViewRepresentable for your DashboardIndicatorProminentView.
struct DashboardIndicatorProminentRepresentable: UIViewRepresentable {
    let prominentView = DashboardIndicatorProminentView()

    /// Example data
    let value: String?
    let superscriptValue: String?
    let subscriptValue: String?
    let showProgress: Bool
    let progressColor: UIColor?

    func makeUIView(context: Context) -> DashboardIndicatorProminentView {
        prominentView
    }

    func updateUIView(_ uiView: DashboardIndicatorProminentView, context: Context) {
        uiView.setValue(
            with: value,
            superscriptValue: superscriptValue,
            subscriptValue: subscriptValue,
            showProgress: showProgress,
            progressColor: progressColor
        )
    }
}

/// 3) The main SwiftUI view that mimics the DashboardViewRow’s layout,
///    while embedding the two custom UIView types via representables.
struct DashboardViewRowSwiftUI: View {
    // Provide your existing data + measurement service
    @ObservedObject var viewModel: CardsViewModel
    var measurementService: RuuviServiceMeasurement?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Example body replicating the structure of DashboardViewRow
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Name label + optional alert icon, etc.
            HStack(alignment: .top, spacing: 8) {
                Text(viewModel.name)
                    .font(.custom("Montserrat-Bold", size: 14))
                    .foregroundColor(RuuviColor.dashboardIndicatorBig.color.toColor())

                // Alert icon if needed
                if let alertIconName = alertIconName() {
                    Image(uiImage: alertIconName)
                        .renderingMode(.template)
                        .foregroundColor(alertIconTintColor())
                }
                // "More" button, etc., would go here if you replicate that logic
            }

            // The "Prominent" indicator row
            DashboardIndicatorProminentRepresentable(
                value: computeProminentValue().value,
                superscriptValue: computeProminentValue().superscriptValue,
                subscriptValue: computeProminentValue().subscriptValue,
                showProgress: computeProminentValue().showProgress,
                progressColor: computeProminentValue().progressColor
            )
            .frame(height: 40) // or as needed

            // Additional indicators in a grid
            buildIndicatorGrid()

            // The row with data source icon + updatedAt + battery
            HStack(spacing: 8) {
                // For a dataSource icon if needed:
                if let dataSourceIcon = dataSourceIcon() {
                    Image(uiImage: dataSourceIcon)
                        .renderingMode(.template)
                        .foregroundColor(RuuviColor
                            .dashboardIndicator.color
                            .withAlphaComponent(0.8)
                            .toColor())
                        .frame(width: 22, height: 22)
                }

                // updatedAt text
                UpdatedAtTextView(date: viewModel.date)
//                Text(updatedAtText() ?? "")
//                    .font(.custom("Muli-Regular", size: 10))
//                    .foregroundColor(RuuviColor
//                        .dashboardIndicator.color
//                        .withAlphaComponent(0.8)
//                        .toColor())

                // Battery indicator if needed, or replicate BatteryLevelView
            }
        }
        .padding(12)
        .background(RuuviColor.dashboardCardBG.color.toColor())
        .cornerRadius(8)
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
        // Example logic if sensor version == 224 => show AQI, else show temperature, etc.
        // Return the data that the ProminentRepresentable needs.
        if (viewModel.version == 224 || viewModel.version == 240),
           let co2 = viewModel.co2 {
            // Example: "AirQuality"
            let current = "2"
            let maximum = "5"
            return (current, "/\(maximum)", "AirQuality", true, .green)
        } else {
            // Example: temperature
            let tempString = measurementService?.stringWithoutSign(for: viewModel.temperature) ?? "N/A"
            return (tempString, "°C", "Temperature", false, nil)
        }
    }

    // MARK: - Helpers for the additional Indicator Grid
    @ViewBuilder
    private func buildIndicatorGrid() -> some View {
        let indicators: [DashboardIndicatorRepresentable] = createIndicatorData()

        if indicators.count < 3 {
            VStack(spacing: 8) {
                ForEach(indicators.indices, id: \.self) { idx in
                    indicators[idx]
                        .frame(height: 24)
                }
            }
        } else {
            // 2 columns
            VStack(spacing: 8) {
                // Convert the stride to an Array:
                ForEach(Array(stride(from: 0, to: indicators.count, by: 2)), id: \.self) { index in
                    HStack(spacing: 8) {
                        indicators[index].frame(height: 24)
                        if index + 1 < indicators.count {
                            indicators[index + 1].frame(height: 24)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    /// Actually build the array of DashboardIndicatorRepresentable
    private func createIndicatorData() -> [DashboardIndicatorRepresentable] {
        var result: [DashboardIndicatorRepresentable] = []

        // Example: Temperature is #1
        if let temperature = measurementService?.stringWithoutSign(for: viewModel.temperature) {
            let unit = measurementService?.units.temperatureUnit.symbol
            let indicator = DashboardIndicatorRepresentable(
                value: temperature,
                unit: unit
            )
            result.append(indicator)
        }
        // Add more humidity, pressure, etc. repeating your original logic:
        // ...
        return result
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
