import UIKit
import RangeSeekSlider

protocol TagSettingsAlertDetailsCellDelegate: AnyObject {
    func didSelectSetCustomDescription(sender: TagSettingsAlertDetailsCell)
    func didSelectAlertLimitDescription(sender: TagSettingsAlertDetailsCell)
    func didChangeAlertState(sender: TagSettingsAlertDetailsCell,
                             didToggle isOn: Bool)
    func didSetAlertRange(sender: TagSettingsAlertDetailsCell,
                          didSlideTo minValue: CGFloat,
                          maxValue: CGFloat)
}

class TagSettingsAlertDetailsCell: UITableViewCell {
    // Public
    weak var delegate: TagSettingsAlertDetailsCellDelegate?

    // Private
    lazy var noticeView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    lazy var noticeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = .label
        label.font = .systemFont(ofSize: 13)
        return label
    }()

    lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Off".localized()
        label.textAlignment = .right
        label.numberOfLines = 0
        label.textColor = .label
        label.font = .systemFont(ofSize: 14)
        return label
    }()

    lazy var statusSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = false
        toggle.addTarget(self, action: #selector(handleStatusToggle), for: .valueChanged)
        return toggle
    }()

    lazy var setCustomDescriptionView = RUAlertDetailsCellChildView()
    lazy var alertLimitDescriptionView = RUAlertDetailsCellChildView()
    lazy var alertLimitSliderView: RURangeSeekSlider = {
        let slider = RURangeSeekSlider()
        slider.minValue = 300
        slider.maxValue = 1100
        slider.selectedMinValue = 300
        slider.selectedMaxValue = 1100
        slider.step = 1
        slider.lineHeight = 4
        slider.handleDiameter = 24
        slider.enableStep = true
        slider.minDistance = 1
        slider.colorBetweenHandles = #colorLiteral(red: 0.08235294118, green: 0.5529411765, blue: 0.6470588235, alpha: 1)
        slider.handleColor = #colorLiteral(red: 0.08235294118, green: 0.5529411765, blue: 0.6470588235, alpha: 1)
        slider.backgroundColor = .clear
        slider.tintColor = .darkGray
        slider.hideLabels = true
        return slider
    }()

    lazy var additionalTextView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    lazy var additionalTextLabel: UILabel = {
        let label = UILabel()
        label.text = "Addtional Text Goes Here"
        label.textAlignment = .right
        label.numberOfLines = 0
        label.textColor = .label
        label.font = .systemFont(ofSize: 14)
        return label
    }()

    // Height constraint variables
    private var noticeViewHeight: NSLayoutConstraint!
    private var alertLimitDescriptionViewHeight: NSLayoutConstraint!
    private var alertLimitSliderViewHeight: NSLayoutConstraint!
    private var additionalTextViewHeight: NSLayoutConstraint!

    // Init
    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpUI()
    }

    // Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        setCustomDescriptionView.delegate = self
        alertLimitDescriptionView.delegate = self
        alertLimitSliderView.delegate = self
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setCustomDescriptionView.delegate = nil
        alertLimitDescriptionView.delegate = nil
    }
}

extension TagSettingsAlertDetailsCell {
    // swiftlint:disable:next function_body_length
    private func setUpUI() {
        backgroundColor = .clear

        addSubview(noticeView)
        noticeView.anchor(top: topAnchor,
                          leading: leadingAnchor,
                          bottom: nil,
                          trailing: trailingAnchor)
        noticeViewHeight = noticeView.heightAnchor.constraint(equalToConstant: 0)
        noticeViewHeight.isActive = true

        noticeView.addSubview(noticeLabel)
        noticeLabel.fillSuperview(padding: .init(top: 8, left: 16, bottom: 8, right: 16))

        let statusContainerView = UIView()
        statusContainerView.backgroundColor = .clear

        addSubview(statusContainerView)
        statusContainerView.anchor(top: noticeView.bottomAnchor,
                            leading: leadingAnchor,
                            bottom: nil,
                            trailing: trailingAnchor,
                            padding: .init(top: 0,
                                           left: 14,
                                           bottom: 0,
                                           right: 16),
                                   size: .init(width: 0, height: 44))

        statusContainerView.addSubview(statusLabel)
        statusLabel.anchor(top: statusContainerView.topAnchor,
                           leading: statusContainerView.leadingAnchor,
                           bottom: statusContainerView.bottomAnchor,
                           trailing: nil)

        statusContainerView.addSubview(statusSwitch)
        statusSwitch.anchor(top: nil,
                            leading: statusLabel.trailingAnchor,
                            bottom: nil,
                            trailing: statusContainerView.trailingAnchor,
                            padding: .init(top: 0, left: 12, bottom: 0, right: 0))
        statusSwitch.centerYInSuperview()

        let statusSeparator = UIView()
        statusSeparator.backgroundColor = .lightGray.withAlphaComponent(0.5)
        addSubview(statusSeparator)
        statusSeparator.anchor(top: statusContainerView.bottomAnchor,
                               leading: leadingAnchor,
                               bottom: nil,
                               trailing: trailingAnchor,
                               size: .init(width: 0, height: 0.5))

        addSubview(setCustomDescriptionView)
        setCustomDescriptionView.anchor(top: statusSeparator.bottomAnchor,
                                        leading: leadingAnchor,
                                        bottom: nil,
                                        trailing: trailingAnchor,
                                        size: .init(width: 0, height: 44))

        let customDescriptionSeparator = UIView()
        customDescriptionSeparator.backgroundColor = .lightGray.withAlphaComponent(0.5)
        addSubview(customDescriptionSeparator)
        customDescriptionSeparator.anchor(top: setCustomDescriptionView.bottomAnchor,
                                          leading: leadingAnchor,
                                          bottom: nil,
                                          trailing: trailingAnchor,
                                          size: .init(width: 0, height: 0.5))

        addSubview(alertLimitDescriptionView)
        alertLimitDescriptionView.anchor(top: customDescriptionSeparator.bottomAnchor,
                                         leading: leadingAnchor,
                                         bottom: nil,
                                         trailing: trailingAnchor)
        alertLimitDescriptionViewHeight = alertLimitDescriptionView
            .heightAnchor
            .constraint(equalToConstant: 44)
        alertLimitDescriptionViewHeight.isActive = true

        addSubview(alertLimitSliderView)
        alertLimitSliderView.anchor(top: alertLimitDescriptionView.bottomAnchor,
                                    leading: leadingAnchor,
                                    bottom: nil,
                                    trailing: trailingAnchor,
                                    padding: .init(top: 0, left: 12, bottom: 8, right: 12))
        alertLimitSliderViewHeight = alertLimitDescriptionView
            .heightAnchor
            .constraint(equalToConstant: 44)
        alertLimitSliderViewHeight.isActive = true

        addSubview(additionalTextView)
        additionalTextView.anchor(top: alertLimitSliderView.bottomAnchor,
                                  leading: leadingAnchor,
                                  bottom: bottomAnchor,
                                  trailing: trailingAnchor)
        additionalTextViewHeight = additionalTextView
            .heightAnchor
            .constraint(equalToConstant: 0)
        additionalTextViewHeight.isActive = true

        additionalTextView.addSubview(additionalTextLabel)
        additionalTextLabel.fillSuperview(padding: .init(top: 0, left: 16, bottom: 0, right: 16))
    }
}

// MARK: - Private action
extension TagSettingsAlertDetailsCell {
    @objc private func handleStatusToggle(_ sender: UISwitch) {
        delegate?.didChangeAlertState(sender: self, didToggle: sender.isOn)
    }
}

// MARK: - Pubic Setters
extension TagSettingsAlertDetailsCell {
    func setCustomDescription(with string: String) {
        setCustomDescriptionView.configure(with: string)
    }

    func setAlertLimitDescription(with string: String) {
        alertLimitDescriptionView.configure(with: string)
    }

    func setAlertAddtionalText(with string: String) {
        additionalTextLabel.text = string
    }

    func hideAlertRangeSetter() {
        alertLimitDescriptionViewHeight.constant = 0
        alertLimitDescriptionView.alpha = 0
        alertLimitSliderViewHeight.constant = 0
        alertLimitSliderView.alpha = 0
    }

    func showAlertRangeSetter() {
        alertLimitDescriptionViewHeight.constant = 44
        alertLimitDescriptionView.alpha = 1
        alertLimitSliderViewHeight.constant = 44
        alertLimitSliderView.alpha = 1
    }

    func hideAdditionalTextview() {
        additionalTextViewHeight.constant = 0
        additionalTextView.alpha = 0
    }

    func showAdditionalTextview() {
        additionalTextViewHeight.constant = 44
        additionalTextView.alpha = 1
    }

    func hideNoticeView() {
        noticeViewHeight.constant = 0
        noticeView.alpha = 0
    }

    func showNoticeView() {
        noticeViewHeight.constant = 44
        noticeView.alpha = 1
    }
}

// MARK: - RUAlertDetailsCellChildViewDelegate
extension TagSettingsAlertDetailsCell: RUAlertDetailsCellChildViewDelegate {
    func didTapView(sender: RUAlertDetailsCellChildView) {
        if sender == setCustomDescriptionView {
            delegate?.didSelectSetCustomDescription(sender: self)
        } else if sender == alertLimitDescriptionView {
            delegate?.didSelectAlertLimitDescription(sender: self)
        }
    }
}

// MARK: - RangeSeekSliderDelegate
extension TagSettingsAlertDetailsCell: RangeSeekSliderDelegate {
    func rangeSeekSlider(_ slider: RangeSeekSlider, didChange minValue: CGFloat, maxValue: CGFloat) {
        delegate?.didSetAlertRange(sender: self, didSlideTo: minValue, maxValue: maxValue)
    }
}
