import SwiftUI

@available(iOS 13.0, *)
struct DaemonsRow: View {

    @EnvironmentObject var env: DaemonsEnvironmentObject
    
    var daemon: DaemonsViewModel

    var index: Int {
        return env.daemons.firstIndex(where: { $0.id == daemon.id })!
    }
    
    var body: some View {
        Toggle(isOn: $env.daemons[index].isOn.value.bound) {
            Text(daemon.title)
        }
    }
}

@available(iOS 13.0, *)
struct DaemonsRow_Previews: PreviewProvider {
    static var previews: some View {
        DaemonsRow(daemon: DaemonsViewModel())
    }
}
