// swiftlint:disable file_length
import RangeSeekSlider
import RuuviLocalization
import UIKit

protocol TagSettingsAlertConfigCellDelegate: AnyObject {
    func didSelectSetCustomDescription(sender: TagSettingsAlertConfigCell)
    func didSelectAlertLimitDescription(sender: TagSettingsAlertConfigCell)
    func didChangeAlertState(
        sender: TagSettingsAlertConfigCell,
        didToggle isOn: Bool
    )
    // When slider is changing we would like to update the labels.
    // But, we will not make endpoint calls.
    func didChangeAlertRange(
        sender: TagSettingsAlertConfigCell,
        didSlideTo minValue: CGFloat,
        maxValue: CGFloat
    )
    // We will make endpoind calls for this method only.
    func didSetAlertRange(
        sender: TagSettingsAlertConfigCell,
        minValue: CGFloat,
        maxValue: CGFloat
    )
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
        label.textColor = RuuviColor.textColor.color.withAlphaComponent(0.6)
        label.font = UIFont.Muli(.regular, size: 12)
        return label
    }()

    lazy var statusSwitch: RuuviSwitchView = {
        let toggleView = RuuviSwitchView(delegate: self)
        toggleView.toggleState(with: false)
        return toggleView
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
        slider.colorBetweenHandles = RuuviColor.tintColor.color
        slider.handleColor = RuuviColor.tintColor.color
        slider.backgroundColor = .clear
        slider.tintColor = RuuviColor.graphAlertColor.color
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
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = RuuviColor.textColor.color
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    private lazy var latestMeasurementLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = RuuviColor.textColor.color.withAlphaComponent(0.5)
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    // Height constraint variables
    private var noticeViewHiddenHeight: NSLayoutConstraint!
    private var alertLimitDescriptionViewHiddenHeight: NSLayoutConstraint!
    private var alertLimitSliderViewHiddenHeight: NSLayoutConstraint!
    private var additionalTextViewHiddenHeight: NSLayoutConstraint!
    private var latestMeasurementLabelHiddenHeight: NSLayoutConstraint!

    private var selectedMinimumValue: CGFloat = 0
    private var selectedMaximumValue: CGFloat = 0

    // Init
    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
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

        backgroundColor = RuuviColor.primary.color

        addSubview(noticeView)
        noticeView.anchor(
            top: topAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor
        )
        noticeViewHiddenHeight = noticeView.heightAnchor.constraint(equalToConstant: 0)
        noticeViewHiddenHeight.isActive = true

        noticeView.addSubview(noticeLabel)
        noticeLabel.fillSuperview(padding: .init(
            top: 8,
            left: 12,
            bottom: 8,
            right: 8
        ))

        let statusContainerView = UIView(color: .clear)

        addSubview(statusContainerView)
        statusContainerView.anchor(
            top: noticeView.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(
                top: 0,
                left: 18,
                bottom: 0,
                right: 16
            ),
            size: .init(width: 0, height: 44)
        )

        statusContainerView.addSubview(statusSwitch)
        statusSwitch.anchor(
            top: nil,
            leading: nil,
            bottom: nil,
            trailing: statusContainerView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 2)
        )
        statusSwitch.sizeToFit()
        statusSwitch.centerYInSuperview()

        let statusSeparator = UIView()
        statusSeparator.backgroundColor = RuuviColor.lineColor.color
        addSubview(statusSeparator)
        statusSeparator.anchor(
            top: statusContainerView.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(top: 0, left: 16, bottom: 0, right: 16),
            size: .init(width: 0, height: 1)
        )

        addSubview(setCustomDescriptionView)
        setCustomDescriptionView.anchor(
            top: statusSeparator.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            size: .init(width: 0, height: 44)
        )

        let customDescriptionSeparator = UIView()
        customDescriptionSeparator.backgroundColor = RuuviColor.lineColor.color
        addSubview(customDescriptionSeparator)
        customDescriptionSeparator.anchor(
            top: setCustomDescriptionView.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(top: 0, left: 16, bottom: 0, right: 16),
            size: .init(width: 0, height: 1)
        )

        addSubview(alertLimitDescriptionView)
        alertLimitDescriptionView.anchor(
            top: customDescriptionSeparator.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor
        )
        alertLimitDescriptionViewHiddenHeight = alertLimitDescriptionView
            .heightAnchor
            .constraint(equalToConstant: 0)

        addSubview(alertLimitSliderView)
        alertLimitSliderView.anchor(
            top: alertLimitDescriptionView.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 4),
            size: .init(width: 0, height: 40)
        )
        alertLimitSliderViewHiddenHeight = alertLimitSliderView
            .heightAnchor
            .constraint(equalToConstant: 0)

        addSubview(additionalTextView)
        additionalTextView.anchor(
            top: alertLimitSliderView.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            size: .init(width: 0, height: 44)
        )
        additionalTextViewHiddenHeight = additionalTextView
            .heightAnchor
            .constraint(equalToConstant: 0)
        additionalTextViewHiddenHeight.isActive = true

        additionalTextView.addSubview(additionalTextLabel)
        additionalTextLabel.fillSuperview(padding: .init(top: 0, left: 14, bottom: 0, right: 16))

        setCustomDescriptionView.delegate = self
        alertLimitDescriptionView.delegate = self
        alertLimitSliderView.delegate = self

        addSubview(latestMeasurementLabel)
        latestMeasurementLabel.anchor(
            top: additionalTextView.bottomAnchor,
            leading: safeLeftAnchor,
            bottom: safeBottomAnchor,
            trailing: safeRightAnchor,
            padding: .init(top: 0, left: 14, bottom: 12, right: 16)
        )
        latestMeasurementLabelHiddenHeight = latestMeasurementLabel.heightAnchor.constraint(
            equalToConstant: 0
        )
        latestMeasurementLabelHiddenHeight.isActive = false
    }

    /// Checks if there is change between two values.
    /// Used for slider value. Due to limitation on the RangeSleekSlider
    /// its impossible to know whether minimum or maximum value is changed
    /// when step = 1 as it resets both value. So, value of 12.34 becomes 12.
    /// So this method returns two if difference between two value is greater
    /// than 1.
    private func isValueChanged(a: CGFloat, b: CGFloat) -> Bool {
        abs(a - b) >= 1
    }
}

// MARK: - RuuviSwitchViewDelegate
extension TagSettingsAlertConfigCell: RuuviSwitchViewDelegate {
    func didChangeSwitchState(sender: RuuviSwitchView, didToggle isOn: Bool) {
        delegate?.didChangeAlertState(sender: self, didToggle: isOn)
    }
}

// MARK: - Pubic Setters

extension TagSettingsAlertConfigCell {
    func setStatus(
        with value: Bool?,
        hideStatusLabel: Bool
    ) {
        statusSwitch.toggleState(with: value ?? false)
        statusSwitch.hideStatusLabel(hide: hideStatusLabel)
    }

    func setCustomDescription(with string: String?) {
        setCustomDescriptionView.configure(with: string)
    }

    func setAlertLimitDescription(description: String?) {
        alertLimitDescriptionView.configure(with: description)
    }

    func setAlertLimitDescription(description: NSMutableAttributedString?) {
        alertLimitDescriptionView.configure(with: description)
    }

    func setAlertRange(
        minValue: CGFloat? = nil,
        selectedMinValue: CGFloat? = nil,
        maxValue: CGFloat? = nil,
        selectedMaxValue: CGFloat? = nil
    ) {
        if let minValue {
            alertLimitSliderView.minValue = minValue
        }

        if let maxValue {
            alertLimitSliderView.maxValue = maxValue
        }

        if let selectedMinValue {
            alertLimitSliderView.selectedMinValue = selectedMinValue
            selectedMinimumValue = selectedMinValue
        }

        if let selectedMaxValue {
            alertLimitSliderView.selectedMaxValue = selectedMaxValue
            selectedMaximumValue = selectedMaxValue
        }
        alertLimitSliderView.refresh()
    }

    func setAlertAddtionalText(with string: String) {
        additionalTextLabel.text = string
    }

    func setNoticeText(with string: String) {
        noticeLabel.text = string
    }

    func setLatestMeasurementText(with string: String) {
        let formattedString = RuuviLocalization.latestMeasuredValue(string)
        latestMeasurementLabel.text = formattedString
    }

    func hideAlertRangeSetter() {
        hideAlertLimitDescription()
        hideAlertRangeSlider()
    }

    func showAlertRangeSetter() {
        showAlertLimitDescription()
        showAlertRangeSlider()
    }

    func hideAlertLimitDescription() {
        alertLimitDescriptionViewHiddenHeight.isActive = true
        alertLimitDescriptionView.alpha = 0
    }

    func showAlertLimitDescription() {
        alertLimitDescriptionViewHiddenHeight.isActive = false
        alertLimitDescriptionView.alpha = 1
    }

    func hideAlertRangeSlider() {
        alertLimitSliderViewHiddenHeight.isActive = true
        alertLimitSliderView.alpha = 0
    }

    func showAlertRangeSlider() {
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

    func hideLatestMeasurement() {
        latestMeasurementLabelHiddenHeight.isActive = true
        latestMeasurementLabel.alpha = 0
    }

    func showLatestMeasurement() {
        latestMeasurementLabelHiddenHeight.isActive = false
        latestMeasurementLabel.alpha = 1
    }

    func disableEditing(
        disable: Bool,
        identifier: TagSettingsSectionIdentifier
    ) {
        statusSwitch.disableEditing(disable: disable)
        setCustomDescriptionView.disable(disable)
        latestMeasurementLabel.disable(disable)

        switch identifier {
        case .alertTemperature, .alertHumidity, .alertPressure:
            alertLimitDescriptionView.disable(disable)
            alertLimitSliderView.disable(disable)
        case .alertRSSI:
            noticeView.disable(disable)
            alertLimitDescriptionView.disable(disable)
            alertLimitSliderView.disable(disable)
        case .alertMovement, .alertConnection:
            additionalTextView.disable(disable)
        default: break
        }
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
    func rangeSeekSlider(_: RangeSeekSlider, didChange minValue: CGFloat, maxValue: CGFloat) {
        let minimumValue =
        isValueChanged(
            a: minValue,
            b: selectedMinimumValue
        ) ? minValue : selectedMinimumValue
        let maximumValue =
        isValueChanged(
            a: maxValue,
            b: selectedMaximumValue
        ) ? maxValue : selectedMaximumValue

        delegate?.didChangeAlertRange(
            sender: self,
            didSlideTo: minimumValue,
            maxValue: maximumValue
        )
    }

    func didEndTouches(in _: RangeSeekSlider) {
        let minimumValue =
        isValueChanged(
            a: alertLimitSliderView.selectedMinValue,
            b: selectedMinimumValue
        ) ? alertLimitSliderView.selectedMinValue : selectedMinimumValue
        let maximumValue =
        isValueChanged(
            a: alertLimitSliderView.selectedMaxValue,
            b: selectedMaximumValue
        ) ? alertLimitSliderView.selectedMaxValue : selectedMaximumValue

        delegate?.didSetAlertRange(
            sender: self,
            minValue: minimumValue,
            maxValue: maximumValue
        )
    }
}

// swiftlint:enable file_length
