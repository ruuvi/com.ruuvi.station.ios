import SwiftUI
import RuuviLocalization

struct TagSettingsView: View {
    @ObservedObject var state: TagSettingsState
    let intent: TagSettingsIntent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                generalSection
                connectivitySection
                Text(RuuviLocalization.TagSettings.Label.Alerts.text.capitalized)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                Text("Alerts UI coming soon")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                diagnosticsSection
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(state.snapshot.displayData.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: intent.onDismiss) {
                    Image(systemName: "chevron.left")
                }
            }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.ownerDisplay)
                .font(.subheadline)
            Button(action: { state.isRenamingSensor = true }) {
                Text(RuuviLocalization.TagSettings.TagNameTitleLabel.text)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }

    private var connectivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(RuuviLocalization.TagSettings.SectionHeader.BTConnection.title.capitalized)
                .font(.headline)
            Toggle(
                RuuviLocalization.TagSettings.PairAndBackgroundScan.Pairing.title,
                isOn: Binding(
                    get: { state.snapshot.connectionData.keepConnection },
                    set: { intent.onToggleKeepConnection($0) }
                )
            )
        }
        .padding(.horizontal)
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(RuuviLocalization.TagSettings.Label.MoreInfo.text.capitalized)
                .font(.headline)
//            if let voltage = state.snapshot.diagnostics.voltage {
//                Text("\(RuuviLocalization.batteryVoltage): \(String(format: \"%.3f\", voltage)) V")
//            }
//            Text(RuuviLocalization.signalStrengthWithUnit + ": " +
//                 (state.snapshot.diagnostics.latestRSSI.map { "\($0) \(RuuviLocalization.dBm)" } ?? RuuviLocalization.na))
        }
        .padding(.horizontal)
    }
}
