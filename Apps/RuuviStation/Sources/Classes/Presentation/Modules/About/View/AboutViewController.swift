import RuuviLocalization
import UIKit

class AboutViewController: UIViewController {
    var output: AboutViewOutput!

    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet var headerTitleLabel: UILabel!
    @IBOutlet var aboutTextView: UITextView!
    @IBOutlet var versionLabel: UILabel!
    @IBOutlet var addedTagsLabel: UILabel!
    @IBOutlet var storedMeasurementsLabel: UILabel!
    @IBOutlet var databaseSizeLable: UILabel!

    private let twoNewlines = "\n\n"
    private let fourNewlines = "\n\n\n\n"

    var viewModel: AboutViewModel = .init()
}

// MARK: - AboutViewInput

extension AboutViewController: AboutViewInput {
    func localize() {
        configureTextView()
        bindViewModel()
    }
}

// MARK: - IBActions

extension AboutViewController {
    @IBAction func backButtonTouchUpInside(_: Any) {
        output.viewDidTriggerClose()
    }
}

// MARK: - View lifecycle

extension AboutViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        setUpChangelogTapGesture()
        localize()
        styleViews()
        output.viewDidLoad()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
        versionLabel.textColor = RuuviColor.dashboardIndicator.color
        addedTagsLabel.textColor = RuuviColor.dashboardIndicator.color
        storedMeasurementsLabel.textColor = RuuviColor.dashboardIndicator.color
        databaseSizeLable.textColor = RuuviColor.dashboardIndicator.color
        aboutTextView.tintColor = RuuviColor.tintColor.color
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async {
            UIView.setAnimationsEnabled(false)
            self.aboutTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            UIView.setAnimationsEnabled(true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        aboutTextView.layoutManager.allowsNonContiguousLayout = false
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            UIView.setAnimationsEnabled(false)
            self.aboutTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            UIView.setAnimationsEnabled(true)
        })
    }
}

// MARK: - UITextViewDelegate

extension AboutViewController: UITextViewDelegate {
    func textView(
        _: UITextView,
        shouldInteractWith URL: URL,
        in _: NSRange,
        interaction _: UITextItemInteraction
    ) -> Bool {
        UIApplication.shared.open(URL, options: [:])
        return false
    }
}

// MARK: - View configuration

extension AboutViewController {
    private func configureViews() {
        dismissButton.setImage(
            RuuviAsset.dismissModalIcon.image,
            for: .normal
        )
        headerTitleLabel.text = RuuviLocalization.About.AboutHelp.header
        configureTextView()
        bindViewModel()
    }

    private func bindViewModel() {
        versionLabel.bind(viewModel.version, block: { label, value in
            label.attributedText = value
        })
        addedTagsLabel.bind(viewModel.addedTags, block: { label, value in
            label.text = value
        })
        storedMeasurementsLabel.bind(viewModel.storedMeasurements, block: { label, value in
            label.text = value
        })
        databaseSizeLable.bind(viewModel.databaseSize, block: { label, value in
            label.text = value
        })
    }

    private func configureTextView() {
        let text =
            RuuviLocalization.About.AboutHelp.contents + fourNewlines +
            RuuviLocalization.About.OperationsManual.header + twoNewlines +
            RuuviLocalization.About.OperationsManual.contents + fourNewlines +
            RuuviLocalization.About.Troubleshooting.header + twoNewlines +
            RuuviLocalization.About.Troubleshooting.contents + fourNewlines +
            RuuviLocalization.About.OpenSource.header + twoNewlines +
            RuuviLocalization.About.OpenSource.contents + fourNewlines +
            RuuviLocalization.About.More.header + twoNewlines +
            RuuviLocalization.About.More.contents + fourNewlines +
            RuuviLocalization.About.Privacy.header + twoNewlines +
            RuuviLocalization.About.Privacy.contents + "\n"

        let attrString = NSMutableAttributedString(string: text)
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.Muli(.regular, size: 16),
            range: range
        )

        // make headers bold
        let makeBold = [
            RuuviLocalization.About.OperationsManual.header,
            RuuviLocalization.About.Troubleshooting.header,
            RuuviLocalization.About.OpenSource.header,
            RuuviLocalization.About.More.header,
            RuuviLocalization.About.Privacy.header,
        ]
        let boldFont = UIFont.Muli(.bold, size: 16)
        for bold in makeBold {
            let range = NSString(string: attrString.string).range(of: bold)
            attrString.addAttribute(NSAttributedString.Key.font, value: boldFont, range: range)
        }
        // reduce the linespacing below the titles
        let smallFont = UIFont.Muli(.regular, size: 8)
        for range in attrString.string.ranges(of: "\n") {
            attrString.addAttribute(
                NSAttributedString.Key.font,
                value: smallFont,
                range: NSRange(range, in: attrString.string)
            )
        }

        // make text color white
        attrString.addAttribute(
            .foregroundColor,
            value: RuuviColor.textColor.color,
            range: NSRange(location: 0, length: attrString.length)
        )

        aboutTextView.attributedText = attrString
        aboutTextView.textColor = RuuviColor.textColor.color
    }

    private func setUpChangelogTapGesture() {
        versionLabel.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleChangelogTap(_:))
        )
        tapGesture.numberOfTouchesRequired = 1
        versionLabel.addGestureRecognizer(tapGesture)
    }

    @objc func handleChangelogTap(_: UITapGestureRecognizer) {
        output.viewDidTapChangelog()
    }
}

private extension String {
    func ranges(of substring: String, options: CompareOptions = [], locale: Locale? = nil) -> [Range<Index>] {
        var ranges: [Range<Index>] = []
        while ranges.last.map({ $0.upperBound < self.endIndex }) ?? true,
              let range = range(
                  of: substring,
                  options: options,
                  range: (ranges.last?.upperBound ?? startIndex) ..< endIndex,
                  locale: locale
              ) {
            ranges.append(range)
        }
        return ranges
    }
}
