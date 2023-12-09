import RuuviLocalization
#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI

@available(iOS 13.0, *)
struct HeartbeatList: View {

    @EnvironmentObject var env: HeartbeatEnvironmentObject

    var body: some View {
        VStack {
            Toggle(isOn: self.$env.viewModel.bgScanningState.value.bound) {
                Text(self.env.viewModel.bgScanningTitle)
            }

            if self.env.viewModel.bgScanningState.value.bound {
                Stepper(RuuviLocalization.Heartbeat.Interval.Every.string
                    + " " + "\(self.env.viewModel.bgScanningInterval.value.bound)"
                        + " " + RuuviLocalization.Heartbeat.Interval.Min.string,
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
