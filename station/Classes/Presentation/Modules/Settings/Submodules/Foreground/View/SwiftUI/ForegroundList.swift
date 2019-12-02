#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Localize_Swift

@available(iOS 13.0, *)
struct ForegroundList: View {

    @EnvironmentObject var env: ForegroundEnvironmentObject

    func index(of daemon: ForegroundViewModel) -> Int {
        return env.daemons.firstIndex(where: { $0.id == daemon.id })!
    }

    var body: some View {
        List {
            ForEach(env.daemons) { daemon in
                Section(header: Text(daemon.section)) {
                    ForegroundRow(daemon: daemon)
                    if daemon.isOn.value.bound {
                        Stepper("Foreground.Interval.Every.string".localized()
                            + " " + "\(daemon.interval.value.bound)"
                            + " " + "Foreground.Interval.Min.string".localized(),
                                value: self.$env.daemons[self.index(of: daemon)].interval.value.bound, in: 1...3600)
                    }
                }
            }

        }.listStyle(GroupedListStyle())
    }
}

@available(iOS 13.0, *)
struct ForegroundList_Previews: PreviewProvider {
    static var previews: some View {
        return ForegroundList().environmentObject(ForegroundEnvironmentObject())
    }
}
#endif
