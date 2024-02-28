import SwiftUI

struct NavigationBarModifier: ViewModifier {
    var backgroundColor: UIColor = .clear

    init(backgroundColor: UIColor, tintColor: UIColor = .label) {
        self.backgroundColor = backgroundColor

        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.backgroundColor = backgroundColor

        UINavigationBar.appearance().titleTextAttributes =
            [NSAttributedString.Key.font: UIFont.Muli(.bold, size: 18)]
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        UINavigationBar.appearance().tintColor = tintColor
    }

    func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                GeometryReader { geometry in
                    Color(self.backgroundColor)
                        .frame(height: geometry.safeAreaInsets.top)
                        .edgesIgnoringSafeArea(.top)
                    Spacer()
                }
            }
        }
    }
}
