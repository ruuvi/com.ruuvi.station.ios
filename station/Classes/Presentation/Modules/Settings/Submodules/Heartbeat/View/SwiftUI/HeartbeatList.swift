#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Localize_Swift

@available(iOS 13.0, *)
struct HeartbeatList: View {

    @EnvironmentObject var env: HeartbeatEnvironmentObject

    var body: some View {
        VStack {
            Toggle(isOn: self.$env.viewModel.saveHeartbeats.value.bound) {
                Text(self.env.viewModel.saveHeartbeatsTitle)
            }

            if self.env.viewModel.saveHeartbeats.value.bound {
                Stepper("Heartbeat.Interval.Every.string".localized()
                    + " " + "\(self.env.viewModel.saveHeartbeatsInterval.value.bound)"
                    + " " + "Heartbeat.Interval.Min.string".localized(),
                        value: self.$env.viewModel.saveHeartbeatsInterval.value.bound,
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
