import UIKit
import Future

class AddMacModalPresenter: NSObject {
    weak var view: AddMacModalViewInput!
    var output: AddMacModalModuleOutput!
    var router: AddMacModalRouterInput!
    private var networkProvider: RuuviNetworkProvider!

    private let macRegex: String = "([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}"
    private var willEnterForegroundToken: NSObjectProtocol!
    private var viewModel: AddMacModalViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
    deinit {
        willEnterForegroundToken.invalidate()
    }
}

// MARK: - AddMacModalViewOutput
extension AddMacModalPresenter: AddMacModalViewOutput {
    func viewDidLoad() {
        createViewModel()
        startObservingWillEnterForeground()
        findMacAddressesInPasteBoard()
    }

    func viewDidTriggerDismiss() {
        router.dismiss()
    }

    func viewDidTriggerSend(mac: String) {
        router.dismiss { [weak self] in
            guard let sSelf = self else {
                return
            }
            sSelf.output.addMacDidEnter(mac, for: sSelf.networkProvider)
        }
    }
}

// MARK: - AddMacModalModuleInput
extension AddMacModalPresenter: AddMacModalModuleInput {
    func configure(output: AddMacModalModuleOutput, for provider: RuuviNetworkProvider) {
        self.networkProvider = provider
        self.output = output
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}

extension AddMacModalPresenter: MacPasteboardAccessoryViewOutput {
    func didSelect(item: String) {
        view.didSelectMacAddress(item.replacingOccurrences(of: ":", with: ""))
    }
}
// MARK: - Private
extension AddMacModalPresenter {
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
        viewModel = AddMacModalViewModel()
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
