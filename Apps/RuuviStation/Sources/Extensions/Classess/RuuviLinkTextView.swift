import RuuviLocalization
import UIKit

protocol RuuviLinkTextViewDelegate: NSObjectProtocol {
    func didTapLink(url: String)
}

class RuuviLinkTextView: UITextView {
    private var textRegularColor: UIColor? = RuuviColor
        .dashboardIndicator.color
        .withAlphaComponent(0.6)
    private var textLinkColor: UIColor? = RuuviColor.textColor.color
    private var fullTextString: String?
    private var linkString: String?
    private var link: String?
    private var fontSize: CGFloat = 13

    private lazy var linkTapGesture = UITapGestureRecognizer(
        target: self, action: #selector(handleTap)
    )

    weak var linkDelegate: RuuviLinkTextViewDelegate?

    convenience init(
        textColor: UIColor? = RuuviColor.textColor.color.withAlphaComponent(0.6),
        linkColor: UIColor? = RuuviColor.textColor.color,
        fullTextString: String?,
        linkString: String?,
        link: String?,
        fontSize: CGFloat = 13
    ) {
        self.init()
        textRegularColor = textColor
        textLinkColor = linkColor
        self.fullTextString = fullTextString
        self.linkString = linkString
        self.link = link
        self.fontSize = fontSize
        setUpUI()
    }

    public func setUpComponents(
        textColor: UIColor? = RuuviColor.textColor.color.withAlphaComponent(0.6),
        linkColor: UIColor? = RuuviColor.textColor.color,
        fullTextString: String?,
        linkString: String?,
        link: String?,
        fontSize: CGFloat = 13
    ) {
        textRegularColor = textColor
        textLinkColor = linkColor
        self.fullTextString = fullTextString
        self.linkString = linkString
        self.link = link
        self.fontSize = fontSize
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
            .font: RuuviFonts.mulish(.regular, size: fontSize, for: .body),
            .foregroundColor: textRegularColor ?? .secondaryLabel,
        ]

        let tappableAttributes: [NSAttributedString.Key: Any] = [
            .font: RuuviFonts.mulish(.bold, size: fontSize, for: .body),
            .foregroundColor: textLinkColor ?? .secondaryLabel,
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

        if linkTapGesture.view !== self {
            addGestureRecognizer(linkTapGesture)
        }
    }

    @objc private func handleTap(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }
        let location = gestureRecognizer.location(in: self)
        guard bounds.contains(location) else { return }
        let textLocation = CGPoint(
            x: location.x - textContainerInset.left,
            y: location.y - textContainerInset.top
        )
        let glyphIndex = layoutManager.glyphIndex(
            for: textLocation, in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        guard glyphIndex < layoutManager.numberOfGlyphs,
              layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: textContainer
              ).contains(textLocation) else { return }
        let position = layoutManager.characterIndexForGlyph(at: glyphIndex)

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
