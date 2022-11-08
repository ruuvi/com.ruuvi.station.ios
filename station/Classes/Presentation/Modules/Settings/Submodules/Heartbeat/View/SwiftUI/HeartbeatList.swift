#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Localize_Swift

@available(iOS 13.0, *)
struct HeartbeatList: View {

    @EnvironmentObject var env: HeartbeatEnvironmentObject

    var body: some View {
        VStack {
            Toggle(isOn: self.$env.viewModel.bgScanningState.value.bound) {
                Text(self.env.viewModel.bgScanningTitle)
            }

            if self.env.viewModel.bgScanningState.value.bound {
                Stepper("Heartbeat.Interval.Every.string".localized()
                    + " " + "\(self.env.viewModel.bgScanningInterval.value.bound)"
                    + " " + "Heartbeat.Interval.Min.string".localized(),
                        value: self.$env.viewModel.bgScanningInterval.value.bound,
                        in: 0...3600)
            }
        }
    }
}

@available(iOS 13.0, *)
struct HeartbeatList_Previews: PreviewProvider {
    static var previews: some View {
        return HeartbeatList().environmentObject(HeartbeatEnvironmentObject())
    }
}
#endif
