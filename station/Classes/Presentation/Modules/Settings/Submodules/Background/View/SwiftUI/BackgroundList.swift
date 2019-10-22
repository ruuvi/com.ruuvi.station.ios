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
                Section() {
                    Toggle(isOn: self.$env.viewModels[self.index(of: viewModel)].isOn.value.bound) {
                        Text(viewModel.name.value.bound)
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
