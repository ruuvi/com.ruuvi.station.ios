import RuuviLocalization
import UIKit

class NoDataView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var container = UIView(
      color: RuuviColor.dashboardCardBG.color
    )

    private lazy var messageLabel: UILabel = {
      let label = UILabel()
      label.textColor = RuuviColor
          .dashboardIndicator.color
          .withAlphaComponent(0.8)
      label.textAlignment = .center
      label.numberOfLines = 0
      label.font = UIFont.ruuviCaptionSmall()
      label.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
      return label
    }()
}

// MARK: Private
extension NoDataView {
    private func setUpUI() {
        addSubview(container)
        container.fillSuperview()

        container.addSubview(messageLabel)
        messageLabel.fillSuperview(
            padding: .init(
            top: 0,
            left: 4,
            bottom: 4,
            right: 4
          )
        )
    }
}
