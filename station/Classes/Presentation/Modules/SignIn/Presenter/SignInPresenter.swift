import Foundation
import Future
import RuuviCloud
import RuuviService
import RuuviUser
import RuuviPresenters
import RuuviDaemon

class SignInPresenter: NSObject {
    enum State {
        case enterEmail
        case enterVerificationCode(_ code: String?)
        case isSyncing
    }

    weak var view: SignInViewInput!
    var output: SignInModuleOutput?
    var router: SignInRouterInput!

    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var ruuviUser: RuuviUser!
    var ruuviCloud: RuuviCloud!
    var cloudSyncService: RuuviServiceCloudSync!
    var cloudSyncDaemon: RuuviDaemonCloudSync!

    private var state: State = .enterEmail
    private var universalLinkObservationToken: NSObjectProtocol?
    private var viewModel: SignInViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }

    deinit {
        universalLinkObservationToken?.invalidate()
    }
}
// MARK: - SignInViewOutput
extension SignInPresenter: SignInViewOutput {
    func viewDidLoad() {
        syncViewModel()
        startObservingUniversalLinks()
        startObservingAppState()
    }

    func viewDidClose() {
        dismiss()
    }

    func viewDidTapSubmitButton() {
        switch state {
        case .enterEmail:
            sendVerificationCode()
        case .enterVerificationCode:
            guard let code = viewModel.inputText.value,
                  !code.isEmpty else {
                viewModel.errorLabelText.value = "SignIn.EnterVerificationCode".localized()
                return
            }
            verify(code)
        case .isSyncing:
            return
        }
    }

    func viewDidTapEnterCodeManually() {
        router.openEmailConfirmation(output: self)
    }
}

// MARK: - SignInModuleOutput
extension SignInPresenter: SignInModuleOutput {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) {
        router.dismiss { [weak self] in
            self?.output?.signIn(module: module, didSuccessfulyLogin: sender)
        }
    }
}

// MARK: - SignInModuleInput
extension SignInPresenter: SignInModuleInput {
    func configure(with state: SignInPresenter.State, output: SignInModuleOutput?) {
        self.output = output
        self.state = state
    }

    func dismiss() {
        if viewModel.canPopViewController.value == true {
            router.popViewController(animated: true)
        } else {
            router.dismiss(completion: nil)
        }
    }
}

// MARK: - Private
extension SignInPresenter {
    @objc private func syncViewModel() {
        viewModel = SignInViewModel()
        switch state {
        case .enterEmail:
            viewModel.titleLabelText.value = "SignIn.TitleLabel.text".localized()
            viewModel.subTitleLabelText.value = "SignIn.SubtitleLabel.text".localized()
            viewModel.placeholder.value = "SignIn.EmailPlaceholder".localized()
            viewModel.submitButtonText.value = "SignIn.RequestCode".localized()
            viewModel.errorLabelText.value = nil
            viewModel.canPopViewController.value = false
            viewModel.textContentType.value = .emailAddress
            viewModel.inputText.value = ruuviUser.email
        case .enterVerificationCode(let code):
            viewModel.titleLabelText.value = "SignIn.TitleLabel.text".localized()
            viewModel.subTitleLabelText.value = "SignIn.CheckMailbox".localized()
            viewModel.placeholder.value = "SignIn.CodeHint".localized()
            viewModel.submitButtonText.value = "SignIn.SubmitCode".localized()
            viewModel.errorLabelText.value = nil
            viewModel.textContentType.value = .name
            if let code = code {
                viewModel.canPopViewController.value = false
                processCode(code)
            }
        case .isSyncing:
            return
        }
        bindViewModel()
    }

    private func bindViewModel() {
        bind(viewModel.inputText) { (presenter, text) in
            switch presenter.state {
            case .enterEmail:
                if let text = text, !text.isEmpty, !presenter.isValidEmail(text) {
                    presenter.viewModel.errorLabelText.value = "UserApiError.ER_INVALID_EMAIL_ADDRESS".localized()
                }
            case .enterVerificationCode:
                if let text = text, text.isEmpty {
                    presenter.viewModel.errorLabelText.value = "SignIn.EnterVerificationCode".localized()
                }
            case .isSyncing:
                return
            }
        }
    }

    private func isValidEmail(_ email: String?) -> Bool {
        guard let email = email else {
            return false
        }
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"

        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func sendVerificationCode() {
        guard let email = viewModel.inputText.value,
              isValidEmail(email) else {
            viewModel.errorLabelText.value = "SignIn.EnterCorrectEmail".localized()
            return
        }
        activityPresenter.increment()
        ruuviCloud.requestCode(email: email)
            .on(success: { [weak self] email in
                guard let sSelf = self else { return }
                sSelf.ruuviUser.email = email
                sSelf.router.openEmailConfirmation(output: sSelf)
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func verify(_ code: String) {
        activityPresenter.increment()
        ruuviCloud.validateCode(code: code)
            .on(success: { [weak self] result in
                guard let sSelf = self else { return }
                if sSelf.ruuviUser.email == result.email {
                    sSelf.ruuviUser.login(apiKey: result.apiKey)
                    sSelf.state = .isSyncing
                    sSelf.cloudSyncService.syncAll().on(success: { [weak sSelf] _ in
                        guard let ssSelf = sSelf else { return }
                        ssSelf.activityPresenter.decrement()
                        ssSelf.cloudSyncDaemon.start()
                        ssSelf.signIn(module: ssSelf, didSuccessfulyLogin: nil)
                    }, failure: { [weak self] error in
                        self?.activityPresenter.decrement()
                        self?.errorPresenter.present(error: error)
                    })
                } else if let requestedEmail = sSelf.ruuviUser.email {
                    sSelf.activityPresenter.decrement()
                    sSelf.view.showEmailsAreDifferent(
                        requestedEmail: requestedEmail,
                        validatedEmail: result.email
                    )
                } else {
                    sSelf.view.showFailedToGetRequestedEmail()
                    sSelf.activityPresenter.decrement()
                }
            }, failure: { [weak self] (error) in
                self?.activityPresenter.decrement()
                self?.errorPresenter.present(error: error)
            })
    }

    private func startObservingUniversalLinks() {
        universalLinkObservationToken = NotificationCenter
            .default
            .addObserver(forName: .DidOpenWithUniversalLink,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            guard let self = self,
                let userInfo = notification.userInfo else {
                return
            }
            self.processLink(userInfo)
        })
    }

    private func startObservingAppState() {
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(handleAppEnterForgroundState),
                         name: UIApplication.willEnterForegroundNotification,
                         object: nil)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(handleAppEnterBackgroundState),
                         name: UIApplication.didEnterBackgroundNotification,
                         object: nil)
    }

    @objc private func handleAppEnterForgroundState() {
        switch state {
        case .isSyncing:
            activityPresenter.increment()
        default:
            return
        }
    }

    @objc private func handleAppEnterBackgroundState() {
        switch state {
        case .isSyncing:
            activityPresenter.decrement()
        default:
            return
        }
    }

    private func processLink(_ userInfo: [AnyHashable: Any]) {
        switch state {
        case .enterVerificationCode:
            guard let path = userInfo["path"] as? UniversalLinkType,
                  path == .verify,
                  let code = userInfo["token"] as? String,
                  !code.isEmpty else {
                return
            }
            self.processCode(code)
        default:
            break
        }
    }

    private func processCode(_ code: String) {
        viewModel.inputText.value = code
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750), execute: { [weak self] in
            self?.verify(code)
        })
    }
}
