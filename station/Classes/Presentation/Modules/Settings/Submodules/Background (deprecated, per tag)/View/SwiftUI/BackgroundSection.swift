#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Localize_Swift

@available(iOS 13.0, *)
struct BackgroundSection: View {
    
    @EnvironmentObject var env: BackgroundEnvironmentObject
    
    var viewModel: BackgroundViewModel
    
    var index: Int {
        return env.viewModels.firstIndex(where: { $0.id == viewModel.id })!
    }
    
    var body: some View {
        VStack {
            Toggle(isOn: self.$env.viewModels[self.index].keepConnection.value.bound) {
                Text(viewModel.keepConnectionTitle)
            }
            if self.env.viewModels[self.index].keepConnection.value.bound {
                Toggle(isOn: self.$env.viewModels[self.index].presentConnectionNotifications.value.bound) {
                    Text(viewModel.presentNotificationsTitle)
                }
                
                Toggle(isOn: self.$env.viewModels[self.index].saveHeartbeats.value.bound) {
                    Text(viewModel.saveHeartbeatsTitle)
                }
                
                if self.env.viewModels[self.index].saveHeartbeats.value.bound {
                    Stepper("Background.Interval.Every.string".localized() + " " + "\(self.env.viewModels[self.index].saveHeartbeatsInterval.value.bound)" + " " + "Background.Interval.Min.string".localized(), value: self.$env.viewModels[self.index].saveHeartbeatsInterval.value.bound, in: 1...3600)
                }
                
                Toggle(isOn: self.$env.viewModels[self.index].readRSSI.value.bound) {
                    Text(viewModel.readRSSITitle)
                }
                
                if self.env.viewModels[self.index].readRSSI.value.bound {
                    Stepper("Background.Interval.Every.string".localized() + " " + "\(self.env.viewModels[self.index].readRSSIInterval.value.bound)" + " " + "Background.Interval.Sec.string".localized(), value: self.$env.viewModels[self.index].readRSSIInterval.value.bound, in: 1...3600)
                }
            }
        }
    }
}

@available(iOS 13.0, *)
struct BackgroundSection_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundSection(viewModel: BackgroundViewModel(uuid: UUID().uuidString))
    }
}
#endif
