import Combine
import UIKit
import SwiftUI
import RuuviLocalization

/// Checkbox state holder
public class RuuviCheckboxViewState: ObservableObject {
    @Published var isChecked: Bool = false
}

/// Ruuvi Checkbox View that is used within the UIKit project
public class RuuviCheckboxViewProvider: NSObject {
    private var stateHolder: RuuviCheckboxViewState

    public var isChecked: Bool {
        stateHolder.isChecked
    }

    public init(stateHolder: RuuviCheckboxViewState) {
        self.stateHolder = stateHolder
    }

    public func makeViewController(title: String) -> UIViewController {
        UIHostingController(
            rootView: RuuviCheckboxView(title: title).environmentObject(stateHolder)
        )
    }
}

/// SwiftUI View that contains the toggle and the title
struct RuuviCheckboxView: View {
    let title: String
    @EnvironmentObject var checkboxState: RuuviCheckboxViewState

    var body: some View {
        Toggle(isOn: $checkboxState.isChecked) {
            Text(
                title
            )
            .font(.ruuviSubheadline())
            .foregroundColor(RuuviColor.textColor.swiftUIColor)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .onTapGesture {
                withAnimation {
                    checkboxState.isChecked.toggle()
                }
            }
        }
        .toggleStyle(CheckboxToggleStyle())
    }
}

// MARK: - View Modifier
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(lineWidth: 3)
                    .fill(RuuviColor.tintColor.swiftUIColor)
                    .background(
                        configuration.isOn ? RuuviColor.tintColor.swiftUIColor : .clear
                    )
                    .cornerRadius(4)
                    .frame(width: 20, height: 20)
                    .onTapGesture {
                        withAnimation {
                            configuration.isOn.toggle()
                        }
                    }
                Image(systemName: "checkmark")
                    .resizable()
                    .foregroundColor(.black)
                    .frame(width: 10, height: 10)
                    .opacity(configuration.isOn ? 1 : 0)
            }
            configuration.label
        }
    }
}
