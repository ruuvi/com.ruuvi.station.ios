import SwiftUI
import UIKit

// MARK: - Sensor Data Model
struct SensorData: Identifiable {
    let id = UUID()
    let sensorName: String
    let airQualityScore: Int
    let airQualityStatus: String
    let temperature: Double
    let humidity: Double
    let pm25: Int
    let nox: Int
    let co2: Int
    let light: Int
    let battery: Double
    let sound: Int
    let syncTime: String
    let hasLowBattery: Bool
}

// MARK: - Sample Data
class SensorDataProvider {
    static let sampleData = [
        SensorData(
            sensorName: "Bathroom",
            airQualityScore: 32,
            airQualityStatus: "Bad",
            temperature: 26.43,
            humidity: 62.34,
            pm25: 27,
            nox: 15,
            co2: 421,
            light: 400,
            battery: 5.5,
            sound: 20,
            syncTime: "15 s ago",
            hasLowBattery: true
        ),
        SensorData(
            sensorName: "Kitchen",
            airQualityScore: 78,
            airQualityStatus: "Good",
            temperature: 24.10,
            humidity: 58.12,
            pm25: 12,
            nox: 8,
            co2: 330,
            light: 550,
            battery: 6.2,
            sound: 42,
            syncTime: "5 s ago",
            hasLowBattery: false
        ),
        SensorData(
            sensorName: "Living Room",
            airQualityScore: 65,
            airQualityStatus: "Moderate",
            temperature: 23.75,
            humidity: 54.50,
            pm25: 18,
            nox: 10,
            co2: 380,
            light: 620,
            battery: 4.2,
            sound: 35,
            syncTime: "30 s ago",
            hasLowBattery: true
        ),
        SensorData(
            sensorName: "Bedroom",
            airQualityScore: 88,
            airQualityStatus: "Excellent",
            temperature: 22.10,
            humidity: 51.20,
            pm25: 8,
            nox: 6,
            co2: 290,
            light: 200,
            battery: 7.8,
            sound: 15,
            syncTime: "10 s ago",
            hasLowBattery: false
        ),
        SensorData(
            sensorName: "Garage",
            airQualityScore: 12,
            airQualityStatus: "Poor",
            temperature: 18.50,
            humidity: 70.30,
            pm25: 35,
            nox: 22,
            co2: 520,
            light: 180,
            battery: 3.8,
            sound: 28,
            syncTime: "2 min ago",
            hasLowBattery: true
        )
    ]
}

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
                    .font(.body)
                    .bold()

                Text(label)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.leading, 8)

            Spacer()
        }
    }
}

// MARK: - Sensor Card View

struct SensorCardView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    let sensor: SensorData

    // Common gauge constants (avoids magic numbers scattered around)
    private let gaugeDiameter: CGFloat = 110
    private let gaugeTrim: CGFloat = 0.75
    private let gaugeRotationDegrees: Double = 135

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            if verticalSizeClass == .compact {
                HStack(spacing: 0) {
                    VStack {
                        Spacer()
                        airQualityGauge
                        airQualityLabels
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

                    Spacer()

                    VStack {
                        airQualityGauge
                        airQualityLabels
                    }

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
    func gradientForAirQualityScore(_ score: CGFloat) -> LinearGradient {
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
            // Background circle (trimmed to 75%)
            Circle()
                .trim(from: 0, to: gaugeTrim)
                .stroke(
                    Color.white.opacity(0.2),
                    lineWidth: 8
                )
                .frame(width: gaugeDiameter, height: gaugeDiameter)
                .rotationEffect(.degrees(gaugeRotationDegrees))

            // Active progress (scaled to fit within that 75% trim)
            Circle()
                .trim(
                    from: 0,
                    to: (CGFloat(sensor.airQualityScore) / 100.0) * gaugeTrim
                )
                .stroke(
                    gradientForAirQualityScore(CGFloat(sensor.airQualityScore)),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: gaugeDiameter, height: gaugeDiameter)
                .rotationEffect(.degrees(gaugeRotationDegrees))

            // Main reading in the center
            Text("\(sensor.airQualityScore)")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)

            // “/ 100” in smaller text
            VStack(spacing: 0) {
                // Keep the same vertical spacing trick
                Text("   ")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)

                Text("/ 100")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 30)
            }
        }
        .padding(.vertical, 20)
    }

    private var airQualityLabels: some View {
        VStack {
            Text(sensor.airQualityStatus)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text("Air Quality")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, -20)
    }

    private var gridColumns: [GridItem] {
        if verticalSizeClass == .compact {
            [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
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
            MetricView(
                icon: "thermometer",
                value: "\(String(format: "%.2f", sensor.temperature)) °C",
                label: "Temperature"
            )

            // Humidity
            MetricView(
                icon: "humidity.fill",
                value: "\(String(format: "%.2f", sensor.humidity)) %",
                label: "Humidity"
            )

            // PM2.5
            MetricView(
                icon: "aqi.medium",
                value: "\(sensor.pm25) µg/m³",
                label: "PM2.5"
            )

            // NOX
            MetricView(
                icon: "drop.fill",
                value: "\(sensor.nox)",
                label: "NOX"
            )

            // CO2
            MetricView(
                icon: "carbon.dioxide.cloud.fill",
                value: "\(sensor.co2) ppm",
                label: "CO₂"
            )

            // Light
            MetricView(
                icon: "lightspectrum.horizontal",
                value: "\(sensor.light) lux",
                label: "Light"
            )

            // Battery
            MetricView(
                icon: "battery.75percent",
                value: "\(String(format: "%.1f", sensor.battery)) V",
                label: "Battery"
            )

            // Sound
            MetricView(
                icon: "waveform.circle",
                value: "\(sensor.sound) dBm",
                label: "Sound"
            )
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
                Text(sensor.syncTime)
                    .foregroundColor(.white.opacity(0.7))
            }

            // Low battery indicator (only if hasLowBattery == true)
            if sensor.hasLowBattery {
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
