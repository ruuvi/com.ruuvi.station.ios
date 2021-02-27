import Foundation
import Future

class SignInPresenter: NSObject {
    enum State {
        case enterEmail
        case enterVerificationCode(_ code: String?)
    }

    weak var view: SignInViewInput!
    var output: SignInModuleOutput?
    var router: SignInRouterInput!

    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var userApi: RuuviNetworkUserApi!

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

// MARK: - TagsManagerModuleOutput
extension SignInPresenter: TagsManagerModuleOutput {}

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
    private func syncViewModel() {
        viewModel = SignInViewModel()
        switch state {
        case .enterEmail:
            viewModel.titleLabelText.value = "SignIn.SignInBenefits".localized()
            viewModel.subTitleLabelText.value = "SignIn.RequestSignLink".localized()
            viewModel.placeholder.value = "SignIn.EmailPlaceholder".localized()
            viewModel.errorLabelText.value = nil
            viewModel.enterCodeManuallyButtonIsHidden.value = false
            viewModel.canPopViewController.value = false
            viewModel.textContentType.value = .emailAddress
            viewModel.inputText.value = keychainService.userApiEmail
        case .enterVerificationCode(let code):
            viewModel.titleLabelText.value = "SignIn.EmailSent".localized()
            viewModel.subTitleLabelText.value = "SignIn.CheckMailbox".localized()
            viewModel.placeholder.value = "SignIn.VerificationCodePlaceholder".localized()
            viewModel.errorLabelText.value = nil
            viewModel.enterCodeManuallyButtonIsHidden.value = true
            viewModel.textContentType.value = .name
            if let code = code {
                viewModel.canPopViewController.value = false
                processCode(code)
            }
        }
        bindViewModel()
    }

    private func bindViewModel() {
        bind(viewModel.inputText) { (presenter, text) in
            switch presenter.state {
            case .enterEmail:
                if !presenter.isValidEmail(text) {
                    presenter.viewModel.errorLabelText.value = "SignIn.EnterCorrectEmail".localized()
                }
            case .enterVerificationCode:
                if text?.isEmpty == true {
                    presenter.viewModel.errorLabelText.value = "SignIn.EnterVerificationCode".localized()
                }
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
        let requestModel = UserApiRegisterRequest(email: email)
        activityPresenter.increment()
        userApi.register(requestModel)
            .on(success: { [weak self] (_) in
                guard let sSelf = self else {
                    return
                }
                sSelf.keychainService.userApiEmail = email
                sSelf.router.openEmailConfirmation(output: sSelf)
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func verify(_ code: String) {
        let requestModel = UserApiVerifyRequest(token: code)
        activityPresenter.increment()
        userApi.verify(requestModel)
            .on(success: { [weak self] (response) in
                guard let sSelf = self else {
                    return
                }
                sSelf.keychainService.ruuviUserApiKey = response.accessToken
                
                sSelf.output?.signIn(module: sSelf, didSuccessfulyLogin: nil)
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
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
