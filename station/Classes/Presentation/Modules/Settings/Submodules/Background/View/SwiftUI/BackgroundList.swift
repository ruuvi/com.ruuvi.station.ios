#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Localize_Swift

@available(iOS 13.0, *)
struct BackgroundList: View {
    
    @EnvironmentObject var env: BackgroundEnvironmentObject
    
    func index(of viewModel: BackgroundViewModel) -> Int {
        return env.viewModels.firstIndex(where: { $0.id == viewModel.id })!
    }
    
    var body: some View {
        List {
            ForEach(env.viewModels) { viewModel in
                Section(header: Text(viewModel.name.value.bound)) {
                    Toggle(isOn: self.$env.viewModels[self.index(of: viewModel)].keepConnection.value.bound) {
                        Text(viewModel.keepConnectionTitle)
                    }
                    if self.env.viewModels[self.index(of: viewModel)].keepConnection.value.bound {
                        Toggle(isOn: self.$env.viewModels[self.index(of: viewModel)].presentConnectionNotifications.value.bound) {
                            Text(viewModel.presentNotificationsTitle)
                        }
                    }
                }
            }
            
        }.listStyle(GroupedListStyle())
    }
}

@available(iOS 13.0, *)
struct BackgroundList_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundList()
    }
}
#endif
