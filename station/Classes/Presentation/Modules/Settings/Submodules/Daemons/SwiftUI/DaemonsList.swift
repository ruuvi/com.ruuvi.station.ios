import SwiftUI

@available(iOS 13.0, *)
struct DaemonsList: View {
    
    @EnvironmentObject var env: DaemonsEnvironmentObject
    
    var body: some View {
        List {
            ForEach(env.daemons) { daemon in
                Section(header: Text(daemon.section)) {
                    DaemonsRow(daemon: daemon)
                }
            }
            
        }.listStyle(GroupedListStyle())
    }
}

@available(iOS 13.0, *)
struct DaemonsList_Previews: PreviewProvider {
    static var previews: some View {
        return DaemonsList().environmentObject(DaemonsEnvironmentObject())
    }
}
