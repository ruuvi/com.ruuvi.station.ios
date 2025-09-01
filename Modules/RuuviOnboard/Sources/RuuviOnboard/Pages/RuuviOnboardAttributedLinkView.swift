import RuuviLocalization
import UIKit

protocol RuuviOnboardAttributedLinkViewDelegate: NSObjectProtocol {
    func didTapLink(url: String)
}

class RuuviOnboardAttributedLinkView: UITextView {
    private var textRegularColor: UIColor = .white
    private var textLinkColor: UIColor = .white
    private var fullTextString: String?
    private var linkString: String?
    private var link: String?

    weak var linkDelegate: RuuviOnboardAttributedLinkViewDelegate?

    convenience init(
        textColor: UIColor = .white,
        linkColor: UIColor = .white,
        fullTextString: String?,
        linkString: String?,
        link: String?
    ) {
        self.init()
        textRegularColor = textColor
        textLinkColor = linkColor
        self.fullTextString = fullTextString
        self.linkString = linkString
        self.link = link
        setUpUI()
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpUI()
    }

    private func setUpUI() {
        isEditable = false
        isScrollEnabled = false
        isUserInteractionEnabled = true
        backgroundColor = .clear
        isSelectable = false

        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.mulish(.semiBoldItalic, size: 15),
            .foregroundColor: textRegularColor,
        ]

        let tappableAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.mulish(.semiBoldItalic, size: 15),
            .foregroundColor: textLinkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: textLinkColor,
        ]

        guard let fullTextString,
              let linkString else { return }

        let attributedText = NSMutableAttributedString(
            string: fullTextString, attributes: regularAttributes
        )

        if let tappableTextRange = fullTextString.range(of: linkString) {
            let nsRange = NSRange(tappableTextRange, in: fullTextString)
            attributedText.addAttributes(tappableAttributes, range: nsRange)
        }

        self.attributedText = attributedText

        let tapGesture = UITapGestureRecognizer(
            target: self, action: #selector(handleTap)
        )
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: self)
        let position = layoutManager.characterIndex(
            for: location, in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        guard let fullTextString,
              let linkString,
              let link else { return }

        if let tappableTextRange = fullTextString.range(of: linkString) {
            let nsRange = NSRange(tappableTextRange, in: fullTextString)

            if NSLocationInRange(position, nsRange) {
                linkDelegate?.didTapLink(url: link)
            }
        }
    }
}
