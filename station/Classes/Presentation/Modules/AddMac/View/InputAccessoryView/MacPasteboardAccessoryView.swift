import UIKit

protocol MacPasteboardAccessoryViewInput {
    func setItems(_ items: [String])
}

protocol MacPasteboardAccessoryViewOutput: class {
    func didSelect(item: String)
}

class MacPasteboardAccessoryView: UIScrollView {

    private let buttonSize: CGSize = CGSize(width: 180, height: 44)
    private(set) lazy var toolBar = {
        return $0
    }(UIToolbar())

    weak var output: MacPasteboardAccessoryViewOutput?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        addSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let itemsCount = toolBar.items?.count ?? 0
        let width = max(UIScreen.main.bounds.width, CGFloat(itemsCount) * buttonSize.width)
        toolBar.frame.size = CGSize(width: width, height: buttonSize.height)
        contentSize = CGSize(width: width, height: buttonSize.height)
    }

    private func configureView() {
        autoresizingMask = toolBar.autoresizingMask
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentSize = toolBar.frame.size
    }

    private func addSubviews() {
        addSubview(toolBar)
    }

    @objc private func didPasteMac(_ sender: UIBarButtonItem) {
        if let text = sender.title {
            output?.didSelect(item: text)
        }
    }
}
extension MacPasteboardAccessoryView: MacPasteboardAccessoryViewInput {
    func setItems(_ items: [String]) {
        isHidden = items.isEmpty
        let buttons: [UIBarButtonItem] = items.map({
            UIBarButtonItem(title: $0,
                            style: .done,
                            target: self,
                            action: #selector(self.didPasteMac(_:)))
        })
        toolBar.setItems(buttons, animated: true)
    }
}
