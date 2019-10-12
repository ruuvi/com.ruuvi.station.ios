#if canImport(SwiftUI)
import SwiftUI
#endif

import Localize_Swift

@available(iOS 13.0, *)
struct DaemonsList: View {
    
    @EnvironmentObject var env: DaemonsEnvironmentObject
    
    func index(of daemon: DaemonsViewModel) -> Int {
        return env.daemons.firstIndex(where: { $0.id == daemon.id })!
    }
    
    var body: some View {
        List {
            ForEach(env.daemons) { daemon in
                Section(header: Text(daemon.section)) {
                    DaemonsRow(daemon: daemon)
                    if daemon.isOn.value.bound {
                        Stepper("Daemons.Interval.Every.string".localized() + " " + "\(daemon.interval.value.bound)" + " " + "Daemons.Interval.Min.string".localized(), value: self.$env.daemons[self.index(of: daemon)].interval.value.bound, in: 1...3600)
                    }
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
