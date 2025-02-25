import SwiftUI
import UIKit
import RuuviLocalization
import RuuviService
import RuuviOntology

// MARK: - Metric View Component
struct MetricView: View {
    let icon: String
    let value: String
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
                Text(value)
                    .font(.muli(.bold, size: 18))
                    .bold()

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
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Spacer()
            Text(value)
                .font(.oswald(.bold, size: 74))
                .bold()
                .padding(.leading, 50)
            Text(unit)
                .font(.oswald(.regular, size: 40))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, -20)
            Spacer()
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
                                if let temperature = viewModel.temperature {
                                    ProminentMetricView(
                                        value: "\(String(format: "%.2f", temperature.value))", unit: "°C"
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

        if normalizedScore <= 0.25 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]), // Red gradient for 0-25
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if normalizedScore <= 0.5 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]), // Orange gradient for 26-50
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if normalizedScore <= 0.75 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.yellow, Color.yellow.opacity(0.8)]), // Yellow gradient for 51-75
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
                _
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
                        lineWidth: 8
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

    private var gridColumns: [GridItem] {
        if verticalSizeClass == .compact {
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
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: 20
        ) {
            // Temperature
            if let version = viewModel.version,
                let temperature = viewModel.temperature {
                let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(
                    from: version
                )
                if firmwareVersion == .e0 || firmwareVersion == .f0 {
                    MetricView(
                        icon: "thermometer",
                        value: "\(String(format: "%.2f", temperature.value)) °C",
                        label: "Temperature"
                    )
                }
            }

            // Humidity
            if let humidity = viewModel.humidity {
                MetricView(
                    icon: "humidity.fill",
                    value: "\(String(format: "%.2f", humidity.value)) %",
                    label: "Humidity"
                )
            }

            // Pressure
            if let pressure = viewModel.pressure {
                MetricView(
                    icon: "wind",
                    value: "\(String(format: "%.2f", pressure.value)) hPa",
                    label: "Pressure"
                )
            }

            // PM2.5
            if let pm2_5 = viewModel.pm2_5 {
                MetricView(
                    icon: "aqi.medium",
                    value: "\(pm2_5) µg/m³",
                    label: "PM2.5"
                )
            }

            // NOX
            if let nox = viewModel.nox {
                MetricView(
                    icon: "drop.fill",
                    value: "\(nox)",
                    label: "NOX"
                )
            }

            // CO2
            if let co2 = viewModel.co2 {
                MetricView(
                    icon: "carbon.dioxide.cloud.fill",
                    value: "\(co2) ppm",
                    label: "CO₂"
                )
            }

            // Light
            if let luminance = viewModel.luminance {
                MetricView(
                    icon: "lightspectrum.horizontal",
                    value: "\(luminance) lux",
                    label: "Light"
                )
            }

            // Battery
            if let voltage = viewModel.voltage {
                MetricView(
                    icon: "battery.75percent",
                    value: "\(String(format: "%.1f", voltage.value)) V",
                    label: "Battery"
                )
            }

            // Sound
            if let dbaAvg = viewModel.dbaAvg {
                MetricView(
                    icon: "waveform.circle",
                    value: "\(dbaAvg) dBm",
                    label: "Sound"
                )
            }

            // Movement
            if let movementCounter = viewModel.movementCounter {
                MetricView(
                    icon: "brakesignal",
                    value: "\(movementCounter)",
                    label: "movements"
                )
            }
        }
        .padding([.top, .horizontal])
    }

    private var statusBar: some View {
        HStack {
            Text("Synchronising...")
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            // Sync time
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .foregroundColor(.white.opacity(0.7))
                Text(viewModel.date?.ruuviAgo() ?? RuuviLocalization.na)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
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
