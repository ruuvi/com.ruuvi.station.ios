import UIKit
import Future

class AddMacPresenter: NSObject {
    weak var view: AddMacViewInput!
    var output: AddMacModuleOutput!
    var router: AddMacRouterInput!
    private var networkProvider: RuuviNetworkProvider!

    private let macRegex: String = "([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}"
    private var willEnterForegroundToken: NSObjectProtocol!
    private var viewModel: AddMacViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
    deinit {
        willEnterForegroundToken.invalidate()
    }
}

// MARK: - AddMacViewOutput
extension AddMacPresenter: AddMacViewOutput {
    func viewDidLoad() {
        createViewModel()
        startObservingWillEnterForeground()
        findMacAddressesInPasteBoard()
    }

    func viewDidTriggerDismiss() {
        router.dismiss()
    }

    func viewDidTriggerSend(mac: String) {
        output.addMac(module: self, didEnter: mac, for: self.networkProvider)
    }
}

// MARK: - AddMacModuleInput
extension AddMacPresenter: AddMacModuleInput {
    func configure(output: AddMacModuleOutput, for provider: RuuviNetworkProvider) {
        self.networkProvider = provider
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss(completion: completion)
    }
}

extension AddMacPresenter: MacPasteboardAccessoryViewOutput {
    func didSelect(item: String) {
        view.didSelectMacAddress(item.replacingOccurrences(of: ":", with: ""))
    }
}
// MARK: - Private
extension AddMacPresenter {
    private func findMacAddressesInPasteBoard() {
        guard let pasteboardString = UIPasteboard.general.string else {
            return
        }
        viewModel.pasteboardDetectedMacs.value = matches(in: pasteboardString)
    }

    private func matches(in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: macRegex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return results.map {
                prepareMatch(                String(text[Range($0.range, in: text)!]))
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    private func prepareMatch(_ match: String) -> String {
        var text = match
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "")
        [2, 5, 8, 11, 14].forEach({
            text.insert(":", at: .init(utf16Offset: $0, in: text))
        })
        return text.uppercased()
    }

    private func createViewModel() {
        viewModel = AddMacViewModel()
        switch networkProvider! {
        case .kaltiot:
            viewModel.title.value = "AddMacViewController.EnterKaltiotMacAddress".localized()
        case .whereOS:
            viewModel.title.value = "AddMacViewController.EnterWhereOsMacAddress".localized()
        }
    }

    private func startObservingWillEnterForeground() {
        willEnterForegroundToken = NotificationCenter
            .default
            .addObserver(forName: UIApplication.willEnterForegroundNotification,
                         object: nil,
                         queue: .main) { [weak self] (_) in
            self?.findMacAddressesInPasteBoard()
        }
    }
}
