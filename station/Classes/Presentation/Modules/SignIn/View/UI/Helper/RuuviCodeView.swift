import Foundation
import UIKit

protocol RuuviCodeViewDelegate: NSObjectProtocol {
    func didFinishTypingCode()
}

class RuuviCodeView: UIStackView {
    // Delegate
    weak var delegate: RuuviCodeViewDelegate?
    var isValidCode: Bool = false

    // Properties
    private let entriesCount: Int = 4
    private var codeEntries: [RuuviCodeTextField] = []

    // Colors
    private let inactiveBorderColor: UIColor = .white.withAlphaComponent(0.2)
    private let textBackgroundColor: UIColor = .white.withAlphaComponent(0.6)
    private let activeBorderColor: UIColor = .white

    // Utils
    private var remainingStrStack: [String] = []

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupSuper()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSuper()
    }
}

// MARK: - Public methods
extension RuuviCodeView {
    // Fill the view with pasted code
    func autofill(with code: String?) {
        guard let code = code else {
            return
        }
        populateRuuviCodeFields(with: code)
    }

    // Returns entered code
    func ruuviCode() -> String {
        return codeEntries.map({ $0.text ?? "" }).joined(separator: "")
    }

    // Activate last field if invalid code is entered
    func reset() {
        codeEntries.removeAll()
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        setupRuuviCodeFields()
    }
}

// MARK: - Private methods
extension RuuviCodeView {
    private func setupSuper() {
        setupStackView()
        setupRuuviCodeFields()
    }

    private func setupStackView() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        translatesAutoresizingMaskIntoConstraints = false
        contentMode = .center
        distribution = .fillEqually
        spacing = 5
    }

    private func setupRuuviCodeFields() {
        for index in 0..<entriesCount {
            let field = RuuviCodeTextField()
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.tag = index
            setupRuuviCodeField(field)
            codeEntries.append(field)
            index != 0 ? (field.previousEntry = codeEntries[index-1]) : (field.previousEntry = nil)
            index != 0 ? (codeEntries[index-1].nextEntry = field) : ()
        }
        if codeEntries.count > 0 {
            codeEntries[0].layer.borderColor = activeBorderColor.cgColor
        }
    }

    private func setupRuuviCodeField(_ textField: RuuviCodeTextField) {
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        addArrangedSubview(textField)
        textField.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        textField.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        textField.widthAnchor.constraint(equalToConstant: 40).isActive = true
        textField.backgroundColor = textBackgroundColor
        textField.textAlignment = .center
        textField.adjustsFontSizeToFitWidth = false
        textField.font = UIFont(name: "Montserrat-Bold", size: 30)
        textField.textColor = .white
        textField.layer.cornerRadius = 5
        textField.layer.borderWidth = 2
        textField.layer.borderColor = inactiveBorderColor.cgColor
        textField.autocorrectionType = .no
        textField.tintColor = .clear
        textField.placeholder = "\u{2022}"
    }

    private func populateRuuviCodeFields(with string: String) {
        remainingStrStack = string.reversed().filter({ $0 != " " }).compactMap { String($0) }
        for textField in codeEntries {
            if let charToAdd = remainingStrStack.popLast() {
                textField.text = String(charToAdd).uppercased()
            } else {
                break
            }
        }
        validateRuuviCodeEntries()
        remainingStrStack = []
    }

    private func validateRuuviCodeEntries() {
        isValidCode = ruuviCode().count == entriesCount
        delegate?.didFinishTypingCode()
    }
}

// MARK: - Textfield Delegate
extension RuuviCodeView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = activeBorderColor.cgColor
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == codeEntries.count - 1 {
            validateRuuviCodeEntries()
        }
        textField.layer.borderColor = inactiveBorderColor.cgColor
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn
                   range: NSRange,
                   replacementString string: String) -> Bool {
        guard let textField = textField as? RuuviCodeTextField else {
            return true
        }
        let code = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if code.count > 1 {
            textField.resignFirstResponder()
            populateRuuviCodeFields(with: code)
            return false
        } else {
            guard textField.previousEntry == nil || textField.previousEntry?.text != "" else {
                return false
            }
            if range.length == 0 && code == "" {
                return false
            } else if range.length == 0 {
                if textField.nextEntry == nil {
                    textField.text? = code.uppercased()
                    textField.resignFirstResponder()
                } else {
                    textField.text? = code.uppercased()
                    textField.nextEntry?.becomeFirstResponder()
                }
                return false
            }
            return true
        }
    }

}
