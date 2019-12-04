#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Localize_Swift

@available(iOS 13.0, *)
struct BackgroundList: View {
    
    @EnvironmentObject var env: BackgroundEnvironmentObject
    
    var body: some View {
        List {
            ForEach(env.viewModels) { viewModel in
                Section(header: Text(viewModel.name.value.bound.uppercased())) {
                    BackgroundSection(viewModel: viewModel)
                }
            }
            
        }.listStyle(GroupedListStyle())
    }
}

@available(iOS 13.0, *)
struct BackgroundList_Previews: PreviewProvider {
    static var previews: some View {
        return BackgroundList().environmentObject(BackgroundEnvironmentObject())
    }
}
#endif
