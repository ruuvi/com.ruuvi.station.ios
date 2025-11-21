import SwiftUI
import UIKit

struct RuuviSwitchRepresentable: UIViewRepresentable {
    @Binding var isOn: Bool
    var isEnabled: Bool
    var showsStatusLabel: Bool
    var onToggle: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> IntrinsicWidthSwitchContainerView {
        let switchView = RuuviSwitchView(
            hideStatusLabel: !showsStatusLabel,
            delegate: context.coordinator
        )
        switchView.toggleState(with: isOn, withAnimation: false)
        switchView.disableEditing(disable: !isEnabled)
        return IntrinsicWidthSwitchContainerView(switchView: switchView)
    }

    func updateUIView(_ uiView: IntrinsicWidthSwitchContainerView, context: Context) {
        context.coordinator.parent = self
        let switchView = uiView.switchView
        switchView.hideStatusLabel(hide: !showsStatusLabel)
        switchView.disableEditing(disable: !isEnabled)
        switchView.toggleState(with: isOn, withAnimation: false)
        uiView.refreshIntrinsicSize()
    }

    @available(iOS 16.0, *)
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: IntrinsicWidthSwitchContainerView,
        context: Context
    ) -> CGSize {
        uiView.intrinsicSwitchSize()
    }

    final class Coordinator: NSObject, RuuviSwitchViewDelegate {
        var parent: RuuviSwitchRepresentable

        init(_ parent: RuuviSwitchRepresentable) {
            self.parent = parent
        }

        func didChangeSwitchState(sender: RuuviSwitchView, didToggle isOn: Bool) {
            parent.onToggle(isOn)
        }
    }
}

/// Wraps `RuuviSwitchView` so SwiftUI respects the UIKit view's intrinsic width.
final class IntrinsicWidthSwitchContainerView: UIView {
    let switchView: RuuviSwitchView

    init(switchView: RuuviSwitchView) {
        self.switchView = switchView
        super.init(frame: .zero)
        backgroundColor = .clear

        addSubview(switchView)
        switchView.fillSuperview()
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        intrinsicSwitchSize()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicSwitchSize()
    }

    func refreshIntrinsicSize() {
        setNeedsLayout()
        layoutIfNeeded()
        invalidateIntrinsicContentSize()
    }

    func intrinsicSwitchSize() -> CGSize {
        switchView.setNeedsLayout()
        switchView.layoutIfNeeded()
        var fittingSize = switchView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        if fittingSize.width == 0 {
            fittingSize.width = switchView.bounds.width
        }
        if fittingSize.height == 0 {
            fittingSize.height = switchView.bounds.height
        }
        return fittingSize
    }
}
