import Foundation
import UIKit

class UpdateFirmwareAppleViewController: UIViewController, UpdateFirmwareViewInput {
    var output: UpdateFirmwareViewOutput!

    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var nextButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
    }

    func localize() {
        title = "UpdateFirmware.Title.text".localized()
        nextButton.setTitle("UpdateFirmware.NextButton.title".localized(), for: .normal)
        configDescriptionContent()
    }

    private func configDescriptionContent() {
        let text = "UpdateFirmware.Download.header".localized() + "\n\n" +
            "UpdateFirmware.Download.content".localized() + "\n\n\n\n" +
            "UpdateFirmware.SetDfu.header".localized() + "\n\n" +
            "UpdateFirmware.SetDfu.content".localized() + "\n\n\n\n"

        let attrString = NSMutableAttributedString(string: text)
        let muliRegular = UIFont.systemFont(ofSize: 16)
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(NSAttributedString.Key.font, value: muliRegular, range: range)

        // make headers bold
        let makeBold = ["UpdateFirmware.Download.header".localized(),
                        "UpdateFirmware.SetDfu.header".localized()]
        let boldFont = UIFont.systemFont(ofSize: 16, weight: .bold)
        for bold in makeBold {
            let range = NSString(string: attrString.string).range(of: bold)
            attrString.addAttribute(NSAttributedString.Key.font, value: boldFont, range: range)
        }

        attrString.addAttribute(.foregroundColor,
                                value: UIColor.darkGray,
                                range: NSRange(location: 0, length: attrString.length))

        descriptionTextView.attributedText = attrString
    }
}

// MARK: - IBOutlet
extension UpdateFirmwareAppleViewController {
    @IBAction func nextButtonAction(_ sender: Any) {
        output.viewDidOpenFlashFirmware()
    }
}
