#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Localize_Swift

@available(iOS 13.0, *)
struct BackgroundList: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello World!"/*@END_MENU_TOKEN@*/)
    }
}

@available(iOS 13.0, *)
struct BackgroundList_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundList()
    }
}
#endif
