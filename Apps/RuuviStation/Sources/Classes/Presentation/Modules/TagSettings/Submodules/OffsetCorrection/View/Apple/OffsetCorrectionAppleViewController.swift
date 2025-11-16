import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

class OffsetCorrectionAppleViewController: UIViewController {
    var output: OffsetCorrectionViewOutput!

    var measurementService: RuuviServiceMeasurement!

    var viewModel = OffsetCorrectionViewModel() {
        didSet {
            bindViewModel()
        }
    }

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAsset.chevronBack.image
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    @IBOutlet var correctedValueTitle: UILabel!
    @IBOutlet var originalValueTitle: UILabel!
    @IBOutlet var descriptionTextView: UITextView!
    @IBOutlet var originalValueLabel: UILabel!
    @IBOutlet var originalValueUpdateTimeLabel: UILabel!
    @IBOutlet var correctedValueLabel: UILabel!
    @IBOutlet var offsetValueLabel: UILabel!
    @IBOutlet var correctedValueView: UIView!
    @IBOutlet var calibrateButton: UIButton!
    @IBOutlet var clearButton: UIButton!

    private var timer: Timer?
    private var updatedAt: Date?

    deinit {
        timer?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        styleViews()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            if let updateAt = self?.updatedAt {
                self?.originalValueUpdateTimeLabel.text = "(\(updateAt.ruuviAgo()))"
            }
        })
        bindViewModel()

        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(
            top: backBarButtonItemView.topAnchor,
            leading: backBarButtonItemView.leadingAnchor,
            bottom: backBarButtonItemView.bottomAnchor,
            trailing: backBarButtonItemView.trailingAnchor,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0),
            size: .init(width: 48, height: 48)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)

        output.viewDidLoad()
    }

    private func bindViewModel() {
        if isViewLoaded {
            bindLabels()
            bindViews()
        }
    }

    private func bindViews() {
        correctedValueView.bind(viewModel.hasOffsetValue) { [weak self] _, hasValue in
            if let hasValue, hasValue == true {
                self?.correctedValueView.isHidden = false
                self?.clearButton.isEnabled = true
                self?.clearButton.alpha = 1
            } else {
                self?.correctedValueView.isHidden = true
                self?.clearButton.isEnabled = false
                self?.clearButton.alpha = 0.3
            }
        }
    }

    private func bindLabels() {
        originalValueLabel.bind(viewModel.originalValue) { [weak self] label, value in
            switch self?.viewModel.type {
            case .humidity:
                label.text = "\((value.bound * 100).round(to: 2))%"
            case .pressure:
                label.text = self?.measurementService.string(
                    for: Pressure(value, unit: .hectopascals),
                    allowSettings: false
                )
            default:
                label.text = self?.measurementService.string(
                    for: Temperature(value, unit: .celsius),
                    allowSettings: false
                )
            }
        }
        originalValueUpdateTimeLabel.bind(viewModel.updateAt) { [weak self] label, date in
            if let date {
                self?.updatedAt = date
                label.text = "(\(date.ruuviAgo()))"
            }
        }
        offsetValueLabel.bind(viewModel.offsetCorrectionValue) { [weak self] label, value in
            let text: String? = switch self?.viewModel.type {
            case .humidity:
                self?.measurementService.humidityOffsetCorrectionString(for: value ?? 0)
            case .pressure:
                self?.measurementService.pressureOffsetCorrectionString(for: value ?? 0)
            default:
                self?.measurementService.temperatureOffsetCorrectionString(for: value ?? 0)
            }

            label.text = "(\(text!))"
        }
        correctedValueLabel.bind(viewModel.correctedValue) { [weak self] label, value in
            switch self?.viewModel.type {
            case .humidity:
                label.text = "\((value.bound * 100).round(to: 2))%"
            case .pressure:
                label.text = self?.measurementService.string(
                    for: Pressure(value, unit: .hectopascals),
                    allowSettings: false
                )
            default:
                label.text = self?.measurementService.string(
                    for: Temperature(value, unit: .celsius),
                    allowSettings: false
                )
            }
        }
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
        originalValueTitle.textColor = RuuviColor.textColor.color
        originalValueLabel.textColor = RuuviColor.textColor.color
        originalValueUpdateTimeLabel.textColor = RuuviColor.textColor.color
        correctedValueTitle.textColor = RuuviColor.textColor.color
        correctedValueLabel.textColor = RuuviColor.textColor.color
        offsetValueLabel.textColor = RuuviColor.textColor.color
        descriptionTextView.tintColor = RuuviColor.tintColor.color
        calibrateButton.backgroundColor = RuuviColor.tintColor.color
        clearButton.backgroundColor = RuuviColor.tintColor.color

        originalValueTitle.font = UIFont.ruuviHeadline()
        originalValueLabel.font = UIFont.ruuviTitle3()
        originalValueUpdateTimeLabel.font = UIFont.ruuviFootnote()
        correctedValueTitle.font = UIFont.ruuviHeadline()
        correctedValueLabel.font = UIFont.ruuviTitle3()
        offsetValueLabel.font = UIFont.ruuviFootnote()
        calibrateButton.titleLabel?.font = UIFont.ruuviButtonMedium()
        clearButton.titleLabel?.font = UIFont.ruuviButtonMedium()
    }
}

extension OffsetCorrectionAppleViewController: OffsetCorrectionViewInput {
    func localize() {
        configDescriptionContent()
        correctedValueTitle.text = RuuviLocalization.OffsetCorrection.CorrectedValue.title
        originalValueTitle.text = RuuviLocalization.OffsetCorrection.OriginalValue.title
        calibrateButton.setTitle(RuuviLocalization.HumidityCalibration.Button.Calibrate.title, for: .normal)
        clearButton.setTitle(RuuviLocalization.HumidityCalibration.Button.Clear.title, for: .normal)
        title = viewModel.title
    }

    private func configDescriptionContent() {
        let text = RuuviLocalization.OffsetCorrection.CalibrationDescription.text

        let attrString = NSMutableAttributedString(string: text)
        let muliRegular = UIFont.ruuviBody()
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(NSAttributedString.Key.font, value: muliRegular, range: range)
        // make text color gray
        attrString.addAttribute(
            .foregroundColor,
            value: RuuviColor.textColor.color,
            range: NSRange(location: 0, length: attrString.length)
        )

        descriptionTextView.attributedText = attrString
        descriptionTextView.textColor = RuuviColor.textColor.color
    }

    func showCalibrateDialog() {
        let title = RuuviLocalization.OffsetCorrection.Dialog.Calibration.title
        var message = ""
        switch viewModel.type {
        case .humidity:
            message = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterHumidity("%")
        case .pressure:
            let format = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterPressure
            let unit = viewModel.pressureUnit.value ?? .hectopascals
            message = format(unit.ruuviSymbol)
        default:
            let format = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterTemperature
            let unit = viewModel.temperatureUnit.value ?? .celsius
            message = format(unit.symbol)
        }

        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addTextField { textfield in
            textfield.keyboardType = .numbersAndPunctuation
        }
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.confirm,
            style: .destructive,
            handler: { [weak self] _ in
                let text = controller.textFields?.first?.text ?? "0.0"
                self?.output.viewDidSetCorrectValue(correctValue: text.doubleValue)
            }
        ))
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showClearConfirmationDialog() {
        let title = RuuviLocalization.OffsetCorrection.Dialog.Calibration.title
        let message = RuuviLocalization.OffsetCorrection.Dialog.Calibration.clearConfirm
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.confirm,
            style: .destructive,
            handler: { [weak self] _ in
                self?.output.viewDidClearOffsetValue()
            }
        ))
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

// MARK: - IBOutlet

extension OffsetCorrectionAppleViewController {
    @IBAction func calibrateButtonAction(_: Any) {
        output.viewDidOpenCalibrateDialog()
    }

    @IBAction func clearButtonAction(_: Any) {
        output.viewDidOpenClearDialog()
    }

    @objc private func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }
}
