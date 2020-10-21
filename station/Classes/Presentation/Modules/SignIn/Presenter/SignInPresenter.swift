import Foundation
import Future

class SignInPresenter: NSObject {
    enum State {
        case enterEmail
        case enterVerificationCode
    }

    weak var view: SignInViewInput!
    var output: SignInModuleOutput!
    var router: SignInRouterInput!
    var keychainService: KeychainService!
    var userApi: RuuviNetworkUserApi!
    var errorPresenter: ErrorPresenter!

    private var state: State = .enterEmail

    private var viewModel: SignInViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - SignInViewOutput
extension SignInPresenter: SignInViewOutput {
    func viewDidLoad() {
        syncViewModel()
        bindViewModel()
    }

    func viewDidClose() {
        dismiss()
    }

    func viewDidTapSubmitButton() {
        switch state {
        case .enterEmail:
            sendVerificationCode()
        case .enterVerificationCode:
            verifyCode()
        }
    }

    func viewDidTapEnterCodeManually() {
        router.openEmailConfirmation(output: self)
    }
}

// MARK: - SignInModuleOutput
extension SignInPresenter: SignInModuleOutput {}

// MARK: - SignInModuleInput
extension SignInPresenter: SignInModuleInput {
    func configure(with state: SignInPresenter.State, output: SignInModuleOutput) {
        self.output = output
        self.state = state
    }

    func dismiss() {
        switch state {
        case .enterEmail:
            router.dismiss(completion: nil)
        case .enterVerificationCode:
            router.popViewController(animated: true)
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
        case .enterVerificationCode:
            viewModel.titleLabelText.value = "SignIn.EmailSent".localized()
            viewModel.subTitleLabelText.value = "SignIn.CheckMailbox".localized()
            viewModel.placeholder.value = "SignIn.VerificationCodePlaceholder".localized()
            viewModel.errorLabelText.value = nil
            viewModel.enterCodeManuallyButtonIsHidden.value = true
            viewModel.canPopViewController.value = true
            viewModel.textContentType.value = .name
        }
    }

    private func bindViewModel() {
        bind(viewModel.inputText) { (presenter, text) in
            switch presenter.state {
            case .enterEmail:
                if !presenter.isValidEmail(text) {
                    presenter.viewModel.errorLabelText.value = "SignIn.EnterCorrectEmail".localized()
                }
            case .enterVerificationCode:
                if text?.isEmpty == false {
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
        userApi.register(requestModel)
            .on(success: { [weak self] (_) in
                guard let sSelf = self else {
                    return
                }
                sSelf.router.openEmailConfirmation(output: sSelf)
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
    }
    private func verifyCode() {
        guard let code = viewModel.inputText.value,
              !code.isEmpty else {
            viewModel.errorLabelText.value = "SignIn.EnterVerificationCode".localized()
            return
        }
        let requestModel = UserApiVerifyRequest(token: code)
        userApi.verify(requestModel)
            .on(success: { [weak self] (response) in
                guard let sSelf = self else {
                    return
                }
                sSelf.keychainService.ruuviUserApiKey = response.accessToken
                // TODO open scene with sensors managing
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
    }
}
