import SwiftUI
import UIKit
import RuuviLocalization
import RuuviService
import RuuviOntology
import Combine
import RuuviLocal

// MARK: - Metric View Component
struct MetricView: View {
    let icon: String
    let value: String
    let unit: String
    let label: String

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.montserrat(.bold, size: 18))
                        .bold()
                    VStack {
                        Spacer()
                        Text(unit)
                            .font(.montserrat(.bold, size: 12))
                            .bold()
                    }
                }

                Text(label)
                    .font(.muli(.regular, size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.leading, 8)

            Spacer()
        }
    }
}

struct ProminentMetricView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Text(value)
                .font(.oswald(.bold, size: 74))
                .bold()
                .padding(.leading, verticalSizeClass == .compact ? 0 : 50)
            Text(unit)
                .font(.oswald(.regular, size: 40))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, -20)
        }
    }
}

// MARK: - viewModel Card View

struct SensorCardView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    let viewModel: CardsViewModel
    var measurementService: RuuviServiceMeasurement?

    // Common gauge constants (avoids magic numbers scattered around)
    private let gaugeDiameter: CGFloat = 110
    private let gaugeTrim: CGFloat = 0.75
    private let gaugeRotationDegrees: Double = 135

    var body: some View {
        ZStack {
            if verticalSizeClass == .compact {
                HStack(spacing: 0) {
                    VStack {
                        Spacer()
                        // Prominent
                        if let version = viewModel.version {
                            let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(
                                from: version
                            )
                            if firmwareVersion == .e0 || firmwareVersion == .f0 {
                                airQualityGauge
                                airQualityLabels
                            } else {
                                if let temperature = viewModel.temperature {
                                    ProminentMetricView(
                                        value: "\(String(format: "%.2f", temperature.value))", unit: "°C"
                                    )
                                }
                            }
                        }
                        Spacer()
                    }.padding()

                    Spacer()
                    VStack {
                        Spacer()
                        metricsGrid
                        Spacer()
                        statusBar
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 0) {

                    VStack {
                        // Prominent
                        if let version = viewModel.version {
                            let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(
                                from: version
                            )
                            if firmwareVersion == .e0 || firmwareVersion == .f0 {
                                airQualityGauge
                                airQualityLabels
                            } else {
                                if let temperature = viewModel.temperature,
                                   let tempValue = measurementService?.stringWithoutSign(for: temperature),
                                   let unit = measurementService?.units.temperatureUnit.symbol {
                                    ProminentMetricView(
                                        value: "\(tempValue)", unit: unit
                                    )
                                }
                            }
                        }
                    }.padding(.top, 40)

                    Spacer()

                    // 3. Metrics Grid
                    metricsGrid
                        .padding(.bottom, 30)

                    // 4. Bottom Status Bar
                    statusBar
                }
            }
        }
        .foregroundColor(.white)
    }
}

// MARK: - Subviews
extension SensorCardView {

    // Function to determine the gradient based on airQualityScore
    func gradientForAirQualityScore(_ score: CGFloat, maxScore: CGFloat) -> LinearGradient {
        let normalizedScore = min(max(score, 0), 100) / 100.0 // Normalize to 0-1

        if normalizedScore <= 0.33 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]), // Red gradient for 0-25
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if normalizedScore <= 0.66 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]), // Orange gradient for 26-50
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]), // Green gradient for 76-100
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    // Gauge for Air Quality
    private var airQualityGauge: some View {
        ZStack {

            if let (
                currentAirQIndex,
                maximumAirQIndex,
                state
            ) = measurementService?.aqiString(
                for: viewModel.co2,
                pm25: viewModel.pm2_5,
                voc: viewModel.voc,
                nox: viewModel.nox
            ) {

                Circle()
                    .trim(from: 0, to: gaugeTrim)
                    .stroke(
                        Color.black.opacity(0.8),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: gaugeDiameter, height: gaugeDiameter)
                    .rotationEffect(.degrees(gaugeRotationDegrees))

                // Active progress (scaled to fit within that 75% trim)
                Circle()
                    .trim(
                        from: 0,
                        to: (
                            CGFloat(currentAirQIndex) / CGFloat(
                                maximumAirQIndex
                            )
                        ) * gaugeTrim
                    )
                    .stroke(
                        gradientForAirQualityScore(
                            CGFloat(currentAirQIndex),
                            maxScore: CGFloat(maximumAirQIndex)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: gaugeDiameter, height: gaugeDiameter)
                    .rotationEffect(.degrees(gaugeRotationDegrees))

                // currentAirQIndex / maxAirQIndex => fraction from 0..1
                let fraction = (CGFloat(currentAirQIndex) / CGFloat(maximumAirQIndex)) * gaugeTrim
                // gaugeTrim * 360 => total degrees of that partial arc
                let endAngle = gaugeRotationDegrees + (Double(fraction) * 360)

                // Pulsating circle at the tip
                // Add shadow to the circle.

                ZStack {
                    // The main circle
                    Circle()
                        .fill(Color(state.color))
                        .frame(width: 8, height: 8)

                    // Glow layer behind it
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(state.color),
                                    Color(state.color).opacity(0.5),
                                    Color(state.color).opacity(0.2),
                                    Color(state.color).opacity(0),
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 14
                            )
                        )
                        .frame(width: 30, height: 30)
                }
                .offset(x: gaugeDiameter / 2)
                .rotationEffect(.degrees(endAngle))

                // Main reading in the center
                Text(currentAirQIndex.stringValue)
                    .font(.oswald(.bold, size: 52))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // “/ 100” in smaller text
                VStack(spacing: 0) {
                    // Keep the same vertical spacing trick
                    Text("   ")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)

                    Text("/ \(maximumAirQIndex.stringValue)")
                        .font(.oswald(.regular, size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 30)
                }

            } else {
                EmptyView()
            }
        }
        .padding(.vertical, 20)
    }

    private var airQualityLabels: some View {
        ZStack {
            if let (
                _,
                _,
                status
            ) = measurementService?.aqiString(
                for: viewModel.co2,
                pm25: viewModel.pm2_5,
                voc: viewModel.voc,
                nox: viewModel.nox
            ) {

                VStack {
                    Text(status.rawValue.capitalized)
                        .font(.muli(.bold, size: 24))
                        .foregroundColor(.white)

                    Text(RuuviLocalization.airQuality)
                        .font(.muli(.bold, size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, -20)

            } else {
                EmptyView()
            }
        }
    }

    private func gridColumns(for firmwareVersion: RuuviFirmwareVersion) -> [GridItem] {
        if verticalSizeClass == .compact {
            if firmwareVersion == .e0 || firmwareVersion == .f0 {
                [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ]
            } else {
                [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ]
            }
        } else {
            [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ]
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: gridColumns(
                for: RuuviFirmwareVersion.firmwareVersion(from: viewModel.version ?? 0)
            ),
            spacing: 20
        ) {
            // Temperature
            if let version = viewModel.version {
                let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(
                    from: version
                )
                if firmwareVersion == .e0 || firmwareVersion == .f0 {
                    if let temperature = viewModel.temperature,
                       let tempValue = measurementService?.stringWithoutSign(for: temperature),
                       let unit = measurementService?.units.temperatureUnit.symbol {
                        MetricView(
                            icon: "thermometer",
                            value: "\(tempValue)",
                            unit: unit,
                            label: "Temperature"
                        )
                    }
                }
            }

            // Humidity
            if let humidity = viewModel.humidity {
                let humidityValue = measurementService?.stringWithoutSign(
                    for: humidity,
                    temperature: viewModel.temperature
                )
                let humidityUnit = measurementService?.units.humidityUnit
                let unitSymbol = humidityUnit == .dew
                    ? measurementService?.units.temperatureUnit.symbol ?? "°C"
                    : humidityUnit?.symbol ?? "%"
                MetricView(
                    icon: "humidity.fill",
                    value: "\(humidityValue ?? "-")",
                    unit: unitSymbol,
                    label: "Humidity"
                )
            }

            // Pressure
            if let pressure = viewModel.pressure,
               let pressureValue = measurementService?.stringWithoutSign(for: pressure),
               let unit = measurementService?.units.pressureUnit.symbol {
                MetricView(
                    icon: "wind",
                    value: "\(pressureValue)",
                    unit: unit,
                    label: "Pressure"
                )
            }

            // CO2
            if let co2 = viewModel.co2,
               let co2Value = measurementService?.co2String(for: co2) {
                MetricView(
                    icon: "carbon.dioxide.cloud.fill",
                    value: "\(co2Value)",
                    unit: RuuviLocalization.unitCo2,
                    label: RuuviLocalization.co2
                )
            }

            // PM2.5
            if let pm2_5 = viewModel.pm2_5,
               let pm25Value = measurementService?.pm25String(for: pm2_5) {
                MetricView(
                    icon: "aqi.medium",
                    value: "\(pm25Value)",
                    unit: RuuviLocalization.unitPm25,
                    label: RuuviLocalization.pm25
                )
            }

            // PM10
            if let pm10 = viewModel.pm10,
               let pm10Value = measurementService?.pm10String(for: pm10) {
                MetricView(
                    icon: "aqi.high",
                    value: "\(pm10Value)",
                    unit: RuuviLocalization.unitPm10,
                    label: RuuviLocalization.pm10
                )
            }

            // NOx
            if let nox = viewModel.nox,
               let noxValue = measurementService?.noxString(for: nox) {
                MetricView(
                    icon: "drop.fill",
                    value: "\(noxValue)",
                    unit: RuuviLocalization.unitNox,
                    label: RuuviLocalization.nox
                )
            }

            // Light (Luminosity)
            if let luminance = viewModel.luminance,
               let luminanceValue = measurementService?.luminosityString(for: luminance) {
                MetricView(
                    icon: "lightbulb.fill",
                    value: "\(luminanceValue)",
                    unit: RuuviLocalization.unitLuminosity,
                    label: RuuviLocalization.luminosity
                )
            }

            // Sound
            if let sound = viewModel.dbaAvg,
               let soundValue = measurementService?.soundAvgString(for: sound) {
                MetricView(
                    icon: "waveform.circle",
                    value: "\(soundValue)",
                    unit: RuuviLocalization.unitSound,
                    label: "Sound"
                )
            }

            // Movement
            if let movementCounter = viewModel.movementCounter {
                MetricView(
                    icon: "arrow.triangle.2.circlepath.circle",
                    value: "\(movementCounter)",
                    unit: "",
                    label: RuuviLocalization.Cards.Movements.title
                )
            }

            // Battery
            if let voltage = viewModel.voltage {
                MetricView(
                    icon: "battery.75percent",
                    value: "\(String(format: "%.1f", voltage.value))",
                    unit: "V",
                    label: "Battery"
                )
            }
        }
        .padding([.top, .horizontal])
    }

    private var statusBar: some View {
        HStack {
            NetworkSyncView(
                viewModel: NetworkSyncViewModel(macId: viewModel.mac)
            )
            .foregroundColor(.white.opacity(0.7))

            Spacer()

            HStack(spacing: 8) {
                Group {
                    if let source = viewModel.source {
                        switch source {
                        case .advertisement, .bgAdvertisement:
                            Image(uiImage: RuuviAsset.iconBluetooth.image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                        case .heartbeat, .log:
                            Image(uiImage: RuuviAsset.iconBluetoothConnected.image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                        case .ruuviNetwork:
                            Image(uiImage: RuuviAsset.iconGateway.image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                        default:
                            EmptyView()
                        }
                    }
                }

                // Keep only the text updating
                UpdatedAtTextView(date: viewModel.date)
            }

            // Low battery indicator (only if hasLowBattery == true)
            if viewModel.batteryNeedsReplacement ?? false {
                HStack(spacing: 4) {
                    Image(systemName: "battery.25")
                        .foregroundColor(.orange)
                    Text("Low battery")
                        .foregroundColor(.orange)
                }
                .padding(.leading, 8)
            }
        }
        .font(.system(size: 14))
        .padding(.horizontal)
    }
}

struct UpdatedAtTextView: View {
    let date: Date?
    @State private var timeAgo: String = ""

    var body: some View {
        Text(timeAgo)
            .foregroundColor(.white.opacity(0.7))
            .lineLimit(1)
            .onAppear {
                startTimer()
            }
    }

    private func startTimer() {
        updateText() // Initial update
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateText()
        }
    }

    private func updateText() {
        timeAgo = date?.ruuviAgo() ?? RuuviLocalization.Cards.UpdatedLabel.NoData.message
    }
}

class NetworkSyncViewModel: ObservableObject {
    @Published var syncStatus: NetworkSyncStatus = .none
    private var notificationCancellable: AnyCancellable?

    let macId: AnyMACIdentifier?

    init(macId: AnyMACIdentifier?) {
        self.macId = macId
        startObservingNetworkSyncNotification()
    }

    private func startObservingNetworkSyncNotification() {
        notificationCancellable = NotificationCenter.default
            .publisher(for: .NetworkSyncDidChangeStatus)
            .compactMap { notification -> NetworkSyncStatus? in
                guard let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                      let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                      mac.any == self.macId
                else {
                    return nil
                }
                return status
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateSyncState(with: status)
            }
    }

    private func updateSyncState(with status: NetworkSyncStatus) {
        withAnimation {
            self.syncStatus = status
        }
    }
}

struct NetworkSyncView: View {
    @StateObject var viewModel: NetworkSyncViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text(syncMessage(for: viewModel.syncStatus))
        }
    }

    private func syncMessage(for status: NetworkSyncStatus) -> String {
        switch status {
        case .none:
            return ""
        case .syncing:
            return RuuviLocalization.TagCharts.Status.serving
        case .complete:
            return RuuviLocalization.synchronized
        case .onError:
            return RuuviLocalization.ErrorPresenterAlert.error
        }
    }
}
