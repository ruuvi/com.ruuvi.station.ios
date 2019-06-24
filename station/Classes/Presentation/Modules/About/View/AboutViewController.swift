import UIKit

class AboutViewController: UIViewController {
    var output: AboutViewOutput!
    
    @IBOutlet weak var aboutTextView: UITextView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
}

// MARK: - AboutViewInput
extension AboutViewController: AboutViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - IBActions
extension AboutViewController {
    
    @IBAction func backButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerClose()
    }
    
}

// MARK: - View lifecycle
extension AboutViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async {
            UIView.setAnimationsEnabled(false)
            self.aboutTextView.scrollRangeToVisible(NSMakeRange(0, 0))
            UIView.setAnimationsEnabled(true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        aboutTextView.layoutManager.allowsNonContiguousLayout = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (context) in
            UIView.setAnimationsEnabled(false)
            self.aboutTextView.scrollRangeToVisible(NSMakeRange(0, 0))
            UIView.setAnimationsEnabled(true)
        })
    }
}

// MARK: - UITextViewDelegate
extension AboutViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL, options: [:])
        return false
    }
}

// MARK: - View configuration
extension AboutViewController {
    private func configureViews() {
        boldifyTextView()
    }
    
    private func boldifyTextView() {
        // this is stupid but for some reasons setting the font to bold in ib did not work
        let attrString = NSMutableAttributedString(attributedString: aboutTextView.attributedText)
        let makeBold = ["ABOUT / HELP", "OPERATIONS MANUAL", "TROUBLESHOOTING", "OPEN-SOURCE", "MORE TO READ"]
        let boldFont = UIFont(name: "Muli-Bold", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .bold)
        for bold in makeBold {
            let range = NSString(string: attrString.string).range(of: bold)
            attrString.addAttribute(NSAttributedString.Key.font, value: boldFont, range: range)
        }
        // .. and this is to reduce the linespacing below the titles
        let smallFont = UIFont(name: "Muli-Bold", size: 8) ?? UIFont.systemFont(ofSize: 8)
        for range in attrString.string.ranges(of: "  ") {
            attrString.addAttribute(NSAttributedString.Key.font, value: smallFont, range: NSRange(range, in: attrString.string))
        }
        aboutTextView.attributedText = attrString
    }
}

private extension String {
    func ranges(of substring: String, options: CompareOptions = [], locale: Locale? = nil) -> [Range<Index>] {
        var ranges: [Range<Index>] = []
        while ranges.last.map({ $0.upperBound < self.endIndex }) ?? true,
            let range = self.range(of: substring, options: options, range: (ranges.last?.upperBound ?? self.startIndex)..<self.endIndex, locale: locale)
        {
            ranges.append(range)
        }
        return ranges
    }
}
