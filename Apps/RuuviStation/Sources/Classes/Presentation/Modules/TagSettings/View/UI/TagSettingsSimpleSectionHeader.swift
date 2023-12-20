import RuuviLocalization
import UIKit

protocol TagSettingsSimpleSectionHeaderDelegate: NSObjectProtocol {}

class TagSettingsSimpleSectionHeader: UIView {
    weak var delegate: TagSettingsSimpleSectionHeaderDelegate?
    private var section: Int = 0

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 18)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {
        backgroundColor = RuuviColor.tagSettingsSectionHeaderColor.color
        addSubview(titleLabel)
        titleLabel.fillSuperviewToSafeArea(
            padding: .init(top: 8, left: 8, bottom: 8, right: 8))
    }

    func setTitle(
        with string: String?,
        section: Int,
        backgroundColor: UIColor? = nil
    ) {
        titleLabel.text = string
        self.section = section
        if let color = backgroundColor {
            self.backgroundColor = color
        } else {
            self.backgroundColor = RuuviColor.tagSettingsSectionHeaderColor.color
        }
    }
}
