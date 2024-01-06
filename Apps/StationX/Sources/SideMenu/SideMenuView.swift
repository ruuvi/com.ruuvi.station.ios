import SwiftUI

struct SideMenuView: View {
    var body: some View {
        VStack {
            // Your menu content here
            Text("Menu Item 1")
            Text("Menu Item 2")
            // etc.
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray)
    }
}
