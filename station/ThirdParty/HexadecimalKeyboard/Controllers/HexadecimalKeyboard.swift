//
//  HexadecimalKeyboard.swift
//  KeyboardCustomAppOnly
//
//  Created by Marcy Vernon on 7/11/20.
//
import UIKit

protocol RemoveKeyboardDelegate: class {
    func removeKeyboard()
}

class HexButton: UIButton {
    var hexCharacter: String = ""
}

class HexadecimalKeyboard: UIView {
    weak var target: UIKeyInput?
    weak var delegate: RemoveKeyboardDelegate?

    var hexadecimalButtons: [HexButton] = [
        "0", "7", "8", "9",
        "4", "5", "6",
        "1", "2", "3",
        "A", "B", "C",
        "D", "E", "F"
        ].map {
        let button = HexButton(type: .system)
        button.commonFormat()
        button.hexCharacter = $0
        button.setTitle("\($0)", for: .normal)
        if #available(iOS 13.0, *) {
            button.backgroundColor = UIColor.secondarySystemGroupedBackground
        } else {
            // Fallback on earlier versions
        }
        button.addTarget(self, action: #selector(didTapHexButton(_:)), for: .touchUpInside)
        return button
    }

    var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.commonFormat()
        button.setTitle("⌫", for: .normal)
        if #available(iOS 13.0, *) {
            button.backgroundColor = UIColor.systemGray4
        } else {
            // Fallback on earlier versions
        }
        button.accessibilityLabel = "Delete"
        button.addTarget(self, action: #selector(didTapDeleteButton(_:)), for: .touchUpInside)
        return button
    }()

    var okButton: UIButton = {
        let button = UIButton(type: .system)
        button.commonFormat()
        button.setTitle("OK", for: .normal)
        if #available(iOS 13.0, *) {
            button.backgroundColor = UIColor.systemGray4
        } else {
            // Fallback on earlier versions
        }
        button.accessibilityLabel = "OK"
        button.addTarget(self, action: #selector(didTapOKButton(_:)), for: .touchUpInside)
        return button
    }()

    var mainStack: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fillEqually
        stackView.spacing      = 10
        stackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return stackView
    }()

    init(target: UIKeyInput) {
        self.target = target
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Actions

extension HexadecimalKeyboard {
    @objc func didTapHexButton(_ sender: HexButton) {
        target?.insertText("\(sender.hexCharacter)")
    }

    @objc func didTapDeleteButton(_ sender: HexButton) {
        target?.deleteBackward()
    }

    @objc func didTapOKButton(_ sender: HexButton) {
        delegate?.removeKeyboard()
    }
}

// MARK: - Private initial configuration methods
private extension HexadecimalKeyboard {
    func configure() {
        if #available(iOS 13.0, *) {
            self.backgroundColor = .systemGray3
        } else {
            // Fallback on earlier versions
        }
        autoresizingMask     = [.flexibleWidth, .flexibleHeight]
        buildKeyboard()
    }

    func buildKeyboard() {
        // MARK: - Add main stackview to keyboard
        mainStack.frame = bounds
        addSubview(mainStack)

        // MARK: - Create stackviews
        let panel1         = createStackView(axis: .vertical)
        let panel2         = createStackView(axis: .vertical)
        let panel2Group    = createStackView(axis: .vertical)
        let panel2Controls = createStackView(axis: .horizontal, distribution: .fillProportionally)

        // MARK: - Create multiple stackviews for numbers
        for row in 0 ..< 3 {
            let panel1Numbers = createStackView(axis: .horizontal)
            panel1.addArrangedSubview(panel1Numbers)
            for column in 0 ..< 3 {
                panel1Numbers.addArrangedSubview(hexadecimalButtons[row * 3 + column + 1])
            }
        }

        // MARK: - Create multiple stackviews for letters
        for row in 0 ..< 2 {
            let panel2Letters = createStackView(axis: .horizontal)
            panel2Group.addArrangedSubview(panel2Letters)
            for column in 0 ..< 3 {
                panel2Letters.addArrangedSubview(hexadecimalButtons[9 + row * 3 + column + 1])
            }
        }

        // MARK: - Nest stackviews
        mainStack.addArrangedSubview(panel1)
        panel1.addArrangedSubview(hexadecimalButtons[0])
        mainStack.addArrangedSubview(panel2)
        panel2.addArrangedSubview(panel2Group)
        panel2.addArrangedSubview(panel2Controls)
        panel2Controls.addArrangedSubview(deleteButton)
        panel2Controls.addArrangedSubview(okButton)
        // MARK: - Constraint - sets okButton width
        panel2Controls.addConstraint(
            NSLayoutConstraint(
                item: okButton,
                attribute: .width,
                relatedBy: .equal,
                toItem: deleteButton,
                attribute: .width,
                multiplier: 2,
                constant: 10
            )
        )
    }

    func createStackView(axis: NSLayoutConstraint.Axis,
                         distribution: UIStackView.Distribution = .fillEqually) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis         = axis
        stackView.distribution = distribution
        stackView.spacing      = 10
        return stackView
    }
}
