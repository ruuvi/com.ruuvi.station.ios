import Combine
import UIKit
import SwiftUI
import RuuviLocalization

public protocol RuuviOnboardCheckboxViewDelegate: NSObjectProtocol {
    func didCheckCheckbox(
        isChecked: Bool,
        sender: RuuviOnboardCheckboxProvider
    )
}

/// Checkbox state holder
public class RuuviOnboardCheckboxState: ObservableObject {
    @Published var isChecked: Bool = false
}

/// Ruuvi Checkbox View that is used within the UIKit project
public class RuuviOnboardCheckboxProvider: NSObject {
    weak var delegate: RuuviOnboardCheckboxViewDelegate?

    private var stateHolder = RuuviOnboardCheckboxState()
    private var cancellables = Set<AnyCancellable>()

    public var isChecked: Bool {
        stateHolder.isChecked
    }

    override init() {
      super.init()
      setupSubscriptions()
    }

    public func makeViewController(
        title: String,
        titleMarkupString: String,
        titleLink: String
    ) -> UIViewController {
        return UIHostingController(
            rootView: RuuviOnboardViewCheckboxView(
                title: title,
                titleMarkupString: titleMarkupString,
                titleLink: titleLink
            ).environmentObject(
                stateHolder
            )
        )
    }

    // MARK: - Private
    private func setupSubscriptions() {
      stateHolder.$isChecked
        .sink { [weak self] isChecked in
            guard let sSelf = self else {
                return
            }
            sSelf.delegate?.didCheckCheckbox(
                isChecked: isChecked,
                sender: sSelf
            )
        }
        .store(in: &cancellables)
    }
}

/// SwiftUI View that contains the toggle and the title
struct RuuviOnboardViewCheckboxView: View {
    let title: String
    let titleMarkupString: String
    let titleLink: String
    @EnvironmentObject var checkboxState: RuuviOnboardCheckboxState
    @State private var height: CGFloat = .zero

    var body: some View {
        Toggle(isOn: $checkboxState.isChecked) {
            TitleView(
                title: title,
                titleMarkupString: titleMarkupString,
                titleLink: titleLink,
                dynamicHeight: $height
            )
            .foregroundColor(.white)
            .frame(
                maxWidth: .infinity,
                minHeight: height,
                alignment: .leading
            )
            .onTapGesture {
                withAnimation {
                    checkboxState.isChecked.toggle()
                }
            }
        }
        .toggleStyle(CheckboxToggleStyle())
        .padding(.vertical)
    }

    struct TitleView: UIViewRepresentable {
        let title: String
        let titleMarkupString: String
        let titleLink: String
        @Binding var dynamicHeight: CGFloat

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, RuuviOnboardAttributedLinkViewDelegate {
            var parent: TitleView

            init(_ parent: TitleView) {
                self.parent = parent
            }

            func didTapLink(url: String) {
                guard let url = URL(string: url) else { return }
                UIApplication.shared.open(url)
            }
        }

        func makeUIView(context: Context) -> RuuviOnboardAttributedLinkView {
            let view = RuuviOnboardAttributedLinkView(
                fullTextString: title,
                linkString: titleMarkupString,
                link: titleLink
            )
            view.linkDelegate = context.coordinator
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            return view
        }

        func updateUIView(_ uiView: RuuviOnboardAttributedLinkView, context: Context) {
            DispatchQueue.main.async {
                dynamicHeight = uiView.sizeThatFits(
                    CGSize(
                        width: uiView.bounds.width,
                        height: CGFloat.greatestFiniteMagnitude
                    )
                ).height
            }
        }
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
