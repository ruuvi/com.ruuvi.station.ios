import SwiftUI

struct Collapsible<Content: View>: View {
    @State var label: () -> Text
    @State var content: () -> Content

    @State private var collapsed: Bool = true

    var body: some View {
        VStack {
            Button(
                action: {
                    self.collapsed.toggle()
                },
                label: {
                    HStack {
                        self.label()
                        Spacer()
                        Image(systemName: self.collapsed ? "chevron.down" : "chevron.up")
                    }
                }
            )
            .buttonStyle(PlainButtonStyle())

            VStack {
                self.content().clipped()
            }
            .frame(
                minWidth: 0,
                maxWidth: .none,
                minHeight: 0,
                maxHeight: collapsed ? 0 : .none
            )
            .animation(.easeOut)
            .transition(.slide)
            .clipped()
        }
    }
}
