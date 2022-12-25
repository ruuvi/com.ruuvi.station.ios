import UIKit
import RangeSeekSlider

protocol TagSettingsAlertConfigCellDelegate: AnyObject {
    func didSelectSetCustomDescription(sender: TagSettingsAlertConfigCell)
    func didSelectAlertLimitDescription(sender: TagSettingsAlertConfigCell)
    func didChangeAlertState(sender: TagSettingsAlertConfigCell,
                             didToggle isOn: Bool)
    // When slider is changing we would like to update the labels.
    // But, we will not make endpoint calls.
    func didChangeAlertRange(sender: TagSettingsAlertConfigCell,
                             didSlideTo minValue: CGFloat,
                             maxValue: CGFloat)
    // We will make endpoind calls for this method only.
    func didSetAlertRange(sender: TagSettingsAlertConfigCell,
                          minValue: CGFloat,
                          maxValue: CGFloat)
}

class TagSettingsAlertConfigCell: UITableViewCell {
    // Public
    weak var delegate: TagSettingsAlertConfigCellDelegate?

    // Private
    private lazy var noticeView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var noticeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = .label
        label.font = .systemFont(ofSize: 13)
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Off".localized()
        label.textAlignment = .right
        label.numberOfLines = 0
        label.textColor = .label
        label.font = .systemFont(ofSize: 14)
        return label
    }()

    private lazy var statusSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = false
        toggle.onTintColor = .clear
        toggle.thumbTintColor = RuuviColor.ruuviTintColor
        toggle.addTarget(self, action: #selector(handleStatusToggle), for: .valueChanged)
        return toggle
    }()

    private lazy var setCustomDescriptionView = RUAlertDetailsCellChildView()
    private lazy var alertLimitDescriptionView = RUAlertDetailsCellChildView()
    private lazy var alertLimitSliderView: RURangeSeekSlider = {
        let slider = RURangeSeekSlider()
        slider.minValue = 300
        slider.maxValue = 1100
        slider.selectedMinValue = 300
        slider.selectedMaxValue = 1100
        slider.step = 1
        slider.lineHeight = 3
        slider.handleDiameter = 18
        slider.enableStep = true
        slider.minDistance = 1
        slider.colorBetweenHandles = RuuviColor.ruuviTintColor
        slider.handleColor = RuuviColor.ruuviTintColor
        slider.backgroundColor = .clear
        slider.tintColor = RuuviColor.ruuviTintColor?.withAlphaComponent(0.2)
        slider.hideLabels = true
        return slider
    }()

    private lazy var additionalTextView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var additionalTextLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.numberOfLines = 0
        label.textColor = .label
        label.font = .systemFont(ofSize: 14)
        return label
    }()

    // Height constraint variables
    private var noticeViewHiddenHeight: NSLayoutConstraint!
    private var alertLimitDescriptionViewHiddenHeight: NSLayoutConstraint!
    private var alertLimitSliderViewHiddenHeight: NSLayoutConstraint!
    private var additionalTextViewHiddenHeight: NSLayoutConstraint!

    // Init
    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError()
    }

    // Lifecycle

    override func prepareForReuse() {
        super.prepareForReuse()
        noticeViewHiddenHeight.isActive = true
        additionalTextViewHiddenHeight.isActive = false
        alertLimitSliderViewHiddenHeight.isActive = false
        additionalTextViewHiddenHeight.isActive = true
    }
}

extension TagSettingsAlertConfigCell {
    // swiftlint:disable:next function_body_length
    private func setUpUI() {
        contentView.isUserInteractionEnabled = true

        backgroundColor = RuuviColor.ruuviPrimary

        addSubview(noticeView)
        noticeView.anchor(top: topAnchor,
                          leading: self.safeLeftAnchor,
                          bottom: nil,
                          trailing: self.safeRightAnchor)
        noticeViewHiddenHeight = noticeView.heightAnchor.constraint(equalToConstant: 0)
        noticeViewHiddenHeight.isActive = true

        noticeView.addSubview(noticeLabel)
        noticeLabel.fillSuperview(padding: .init(top: 8,
                                                 left: 8,
                                                 bottom: 8,
                                                 right: 8))

        let statusContainerView = UIView()
        statusContainerView.backgroundColor = .clear

        addSubview(statusContainerView)
        statusContainerView.anchor(top: noticeView.bottomAnchor,
                                   leading: self.safeLeftAnchor,
                                   bottom: nil,
                                   trailing: self.safeRightAnchor,
                                   padding: .init(top: 0,
                                                  left: 18,
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
        statusSeparator.backgroundColor = RuuviColor.ruuviLineColor
        addSubview(statusSeparator)
        statusSeparator.anchor(top: statusContainerView.bottomAnchor,
                               leading: self.safeLeftAnchor,
                               bottom: nil,
                               trailing: self.safeRightAnchor,
                               padding: .init(top: 0, left: 16, bottom: 0, right: 16),
                               size: .init(width: 0, height: 1))

        addSubview(setCustomDescriptionView)
        setCustomDescriptionView.anchor(top: statusSeparator.bottomAnchor,
                                        leading: self.safeLeftAnchor,
                                        bottom: nil,
                                        trailing: self.safeRightAnchor,
                                        size: .init(width: 0, height: 44))

        let customDescriptionSeparator = UIView()
        customDescriptionSeparator.backgroundColor = RuuviColor.ruuviLineColor
        addSubview(customDescriptionSeparator)
        customDescriptionSeparator.anchor(top: setCustomDescriptionView.bottomAnchor,
                                          leading: self.safeLeftAnchor,
                                          bottom: nil,
                                          trailing: self.safeRightAnchor,
                                          padding: .init(top: 0, left: 16, bottom: 0, right: 16),
                                          size: .init(width: 0, height: 1))

        addSubview(alertLimitDescriptionView)
        alertLimitDescriptionView.anchor(top: customDescriptionSeparator.bottomAnchor,
                                         leading: self.safeLeftAnchor,
                                         bottom: nil,
                                         trailing: self.safeRightAnchor,
                                         size: .init(width: 0, height: 44))
        alertLimitDescriptionViewHiddenHeight = alertLimitDescriptionView
            .heightAnchor
            .constraint(equalToConstant: 0)

        addSubview(alertLimitSliderView)
        alertLimitSliderView.anchor(top: alertLimitDescriptionView.bottomAnchor,
                                    leading: self.safeLeftAnchor,
                                    bottom: nil,
                                    trailing: self.safeRightAnchor,
                                    padding: .init(top: 0, left: 0, bottom: 0, right: 4),
                                    size: .init(width: 0, height: 40))
        alertLimitSliderViewHiddenHeight = alertLimitSliderView
            .heightAnchor
            .constraint(equalToConstant: 0)

        addSubview(additionalTextView)
        additionalTextView.anchor(top: alertLimitSliderView.bottomAnchor,
                                  leading: self.safeLeftAnchor,
                                  bottom: self.safeBottomAnchor,
                                  trailing: self.safeRightAnchor,
                                  size: .init(width: 0, height: 44))
        additionalTextViewHiddenHeight = additionalTextView
            .heightAnchor
            .constraint(equalToConstant: 0)
        additionalTextViewHiddenHeight.isActive = true

        additionalTextView.addSubview(additionalTextLabel)
        additionalTextLabel.fillSuperview(padding: .init(top: 0, left: 16, bottom: 0, right: 16))

        setCustomDescriptionView.delegate = self
        alertLimitDescriptionView.delegate = self
        alertLimitSliderView.delegate = self
    }
}

// MARK: - Private action
extension TagSettingsAlertConfigCell {
    @objc private func handleStatusToggle(_ sender: UISwitch) {
        delegate?.didChangeAlertState(sender: self, didToggle: sender.isOn)
    }
}

// MARK: - Pubic Setters
extension TagSettingsAlertConfigCell {
    func setStatus(with value: Bool?) {
        if let value = value {
            statusLabel.text = value ? "On".localized() : "Off".localized()
            statusSwitch.setOn(value, animated: false)
        }
    }

    func setCustomDescription(with string: String?) {
        setCustomDescriptionView.configure(with: string)
    }

    func setAlertLimitDescription(description: String?) {
        alertLimitDescriptionView.configure(with: description)
    }

    func setAlertRange(minValue: CGFloat? = nil,
                       selectedMinValue: CGFloat? = nil,
                       maxValue: CGFloat? = nil,
                       selectedMaxValue: CGFloat? = nil) {
        if let minValue = minValue {
            alertLimitSliderView.minValue = minValue
        }

        if let maxValue = maxValue {
            alertLimitSliderView.maxValue = maxValue
        }

        if let selectedMinValue = selectedMinValue {
            alertLimitSliderView.selectedMinValue = selectedMinValue
        }

        if let selectedMaxValue = selectedMaxValue {
            alertLimitSliderView.selectedMaxValue = selectedMaxValue
        }
    }

    func setAlertAddtionalText(with string: String) {
        additionalTextLabel.text = string
    }

    func setNoticeText(with string: String) {
        noticeLabel.text = string
    }

    func hideAlertRangeSetter() {
        alertLimitDescriptionViewHiddenHeight.isActive = true
        alertLimitDescriptionView.alpha = 0
        alertLimitSliderViewHiddenHeight.isActive = true
        alertLimitSliderView.alpha = 0
    }

    func showAlertRangeSetter() {
        alertLimitDescriptionViewHiddenHeight.isActive = false
        alertLimitDescriptionView.alpha = 1
        alertLimitSliderViewHiddenHeight.isActive = false
        alertLimitSliderView.alpha = 1
    }

    func hideAdditionalTextview() {
        additionalTextViewHiddenHeight.isActive = true
        additionalTextView.alpha = 0
    }

    func showAdditionalTextview() {
        additionalTextViewHiddenHeight.isActive = false
        additionalTextView.alpha = 1
    }

    func hideNoticeView() {
        noticeViewHiddenHeight.isActive = true
        noticeView.alpha = 0
    }

    func showNoticeView() {
        noticeViewHiddenHeight.isActive = false
        noticeView.alpha = 1
    }
}

// MARK: - RUAlertDetailsCellChildViewDelegate
extension TagSettingsAlertConfigCell: RUAlertDetailsCellChildViewDelegate {
    func didTapView(sender: RUAlertDetailsCellChildView) {
        if sender == setCustomDescriptionView {
            delegate?.didSelectSetCustomDescription(sender: self)
        } else if sender == alertLimitDescriptionView {
            delegate?.didSelectAlertLimitDescription(sender: self)
        }
    }
}

// MARK: - RangeSeekSliderDelegate
extension TagSettingsAlertConfigCell: RangeSeekSliderDelegate {
    func rangeSeekSlider(_ slider: RangeSeekSlider, didChange minValue: CGFloat, maxValue: CGFloat) {
        delegate?.didChangeAlertRange(sender: self,
                                      didSlideTo: minValue,
                                      maxValue: maxValue)
    }

    func didEndTouches(in slider: RangeSeekSlider) {
        delegate?.didSetAlertRange(sender: self,
                                   minValue: alertLimitSliderView.selectedMinValue,
                                   maxValue: alertLimitSliderView.selectedMaxValue)
    }
}
