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
    /// Kept alive so its sizing options stay in effect: only its view is embedded in the page.
    private var hostingController: UIViewController?

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
        let controller = UIHostingController(
            rootView: RuuviOnboardViewCheckboxView(
                title: title,
                titleMarkupString: titleMarkupString,
                titleLink: titleLink
            ).environmentObject(
                stateHolder
            )
        )
        // The view is laid out with Auto Layout: update its height whenever the text needs another
        // height (it wraps differently after the page width changed).
        controller.sizingOptions = .intrinsicContentSize
        hostingController = controller
        return controller
    }

    public func setChecked(_ isChecked: Bool) {
        stateHolder.isChecked = isChecked
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
        .padding(.vertical, 4)
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

            /// After the current layout pass, measures the height the text needs at the view's
            /// width and stores it as the title's minimum height.
            func measureHeight(of view: RuuviOnboardAttributedLinkView) {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view else { return }
                    let height = view.sizeThatFits(
                        CGSize(
                            width: view.bounds.width,
                            height: CGFloat.greatestFiniteMagnitude
                        )
                    ).height
                    guard height != self.parent.dynamicHeight else { return }
                    self.parent.dynamicHeight = height
                }
            }
        }

        func makeUIView(context: Context) -> RuuviOnboardAttributedLinkView {
            let view = RuuviOnboardAttributedLinkView(
                fullTextString: title,
                linkString: titleMarkupString,
                link: titleLink
            )
            view.linkDelegate = context.coordinator
            // SwiftUI does not update the view when only its width changes (the page was resized),
            // so measure again whenever the text view gets another width.
            view.onWidthChange = { [weak coordinator = context.coordinator] textView in
                coordinator?.measureHeight(of: textView)
            }
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            return view
        }

        func updateUIView(_ uiView: RuuviOnboardAttributedLinkView, context: Context) {
            context.coordinator.parent = self
            context.coordinator.measureHeight(of: uiView)
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
