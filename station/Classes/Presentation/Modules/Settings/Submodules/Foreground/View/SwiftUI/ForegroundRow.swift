#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI

@available(iOS 13.0, *)
struct ForegroundRow: View {

    @EnvironmentObject var env: ForegroundEnvironmentObject
    
    var daemon: ForegroundViewModel

    var index: Int {
        return env.daemons.firstIndex(where: { $0.id == daemon.id })!
    }
    
    var body: some View {
        Toggle(keepConnection: $env.daemons[index].keepConnection.value.bound) {
            Text(daemon.title)
        }
    }
}

@available(iOS 13.0, *)
struct ForegroundRow_Previews: PreviewProvider {
    static var previews: some View {
        ForegroundRow(daemon: ForegroundViewModel())
    }
}
#endif
