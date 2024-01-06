import ComposableArchitecture
import SwiftUI

struct DashboardView: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                VStack {
                    HStack {
                        Button {
                            withAnimation {
                                _ = store.send(.toggleMenu)
                            }
                        } label: {
                            Image(systemName: "line.horizontal.3")
                                .imageScale(.large)
                        }
                        Spacer()
                    }
                    .padding()
                    List {
                        ForEachStore(store.scope(state: \.sortedTags, action: \.item)) { store in
                            DashboardItemView(store: store)
                        }
                    }
                    Button {
                        store.send(.startListening)
                    } label: {
                        Text("Start")
                    }.padding()
                    Button {
                        store.send(.stopListening)
                    } label: {
                        Text("Stop")
                    }.padding()
                }

                // Side menu
                if store.isMenuOpen {
                    HStack {
                        SideMenuView()
                            .frame(width: 250)
                            .transition(.move(edge: .leading))
                        Spacer()
                    }
                }
            }
            .gesture(dragGesture)
        }
    }

    var dragGesture: some Gesture {
        DragGesture()
            .onEnded {
                if $0.translation.width < -100 {
                    store.send(.toggleMenu)
                }
            }
    }
}
