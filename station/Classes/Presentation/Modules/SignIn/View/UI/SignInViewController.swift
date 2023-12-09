import RuuviLocalization
import Foundation
import UIKit

class SignInViewController: UIViewController {

    // Configuration
    var output: SignInViewOutput!

    var viewModel: SignInViewModel! {
        didSet {
            bindViewModel()
        }
    }

    var fromDeepLink: Bool = false {
        didSet {
            shouldAvoidVerifying = fromDeepLink
        }
    }

    // UI Componenets starts
    private lazy var backButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: RuuviAssets.backButtonImage,
                                     style: .plain,
                                     target: self,
                                     action: #selector(handleBackButtonTap))
        button.tintColor = .white
        return button
    }()

    private lazy var bgLayer: UIImageView = {
        let iv = UIImageView(image: RuuviAssets.signInBgLayer)
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private lazy var signInView = SignInView()
    private lazy var signInVerifyView = SignInVerifyView()

    private lazy var useWithoutAccountButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        button.setTitle(RuuviLocalization.useWithoutAccount,
                        for: .normal)
        button.titleLabel?.font = UIFont.Muli(.semiBoldItalic, size: 14)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.addTarget(self,
                         action: #selector(handleUseWithoutAccountTap),
                         for: .touchUpInside)
        button.underline()
        return button
    }()

    // ---------------------
    private var shouldAvoidVerifying: Bool = false

}

// MARK: - VIEW LIFE CYCLE
extension SignInViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.makeTransparent()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.resetStyleToDefault()
    }
}

extension SignInViewController {
    @objc fileprivate func handleBackButtonTap() {
        output.viewDidTapBack()
    }

    @objc fileprivate func handleUseWithoutAccountTap() {
        output.viewDidTapUseWithoutAccount()
    }

    private func bindViewModel() {
        guard isViewLoaded else {
            return
        }

        view.bind(viewModel.showVerficationScreen) { [weak self] (_, verificationPage) in
            let showVerificationPage = GlobalHelpers.getBool(from: verificationPage)
            self?.signInVerifyView.alpha = showVerificationPage ? 1 : 0
            self?.signInView.alpha = showVerificationPage ? 0 : 1
            self?.useWithoutAccountButton.alpha = showVerificationPage ? 0 : 1
        }

        signInView.bind(viewModel.inputText) { (view, text) in
            if view.enteredEmail() != text {
                view.populateEmail(from: text)
            }
        }

        signInVerifyView.bind(viewModel.inputText) { (view, text) in
            view.populate(from: text)
        }
    }
}

extension SignInViewController: SignInViewInput {
    func localize() {
        // No op.
    }

    func showEmailsAreDifferent(requestedEmail: String, validatedEmail: String) {
        let message = RuuviLocalization.SignIn.EmailMismatch.Alert.message(requestedEmail, validatedEmail, requestedEmail)
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showFailedToGetRequestedEmail() {
        let message = RuuviLocalization.SignIn.EmailMissing.Alert.message
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showInvalidTokenEntered() {
        signInVerifyView.reset()
    }

    func showInvalidEmailEntered() {
        let message = RuuviLocalization.UserApiError.erInvalidEmailAddress
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)

    }
}

extension SignInViewController: SignInViewDelegate {
    func didTapRequestCodeButton(sender: SignInView) {
        let email = sender.enteredEmail()
        output.viewDidTapRequestCodeButton(for: email)
        signInVerifyView.updateMessage(with: email)
    }
}

extension SignInViewController: SignInVerifyViewDelegate {
    func didFinishTypingCode(code: String, sender: SignInVerifyView) {
        if !shouldAvoidVerifying {
            output.viewDidTapEnterCodeManually(code: code)
        }
    }
}

// MARK: - PRIVATE UI SETUP
extension SignInViewController {
    private func setUpUI() {
        setUpNavBarView()
        setUpBase()
        setUpSignInView()
        setUpSignInVerifyView()
        setUpFooterView()
    }

    private func setUpBase() {
        view.backgroundColor = RuuviColor.ruuviPrimary

        view.addSubview(bgLayer)
        bgLayer.fillSuperview()

        view.addSubview(scrollView)
        scrollView.anchor(top: view.safeTopAnchor,
                          leading: nil,
                          bottom: view.bottomAnchor,
                          trailing: nil)
        scrollView.centerXInSuperview()
        scrollView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    }

    fileprivate func setUpNavBarView() {
        navigationItem.leftBarButtonItem = backButton
    }

    private func setUpSignInView() {
        scrollView.addSubview(signInView)
        signInView.anchor(top: scrollView.topAnchor,
                         leading: nil,
                         bottom: nil,
                         trailing: nil)
        signInView.centerXInSuperview()
        signInView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        signInView.alpha = 1
        signInView.delegate = self
    }

    private func setUpSignInVerifyView() {
        scrollView.addSubview(signInVerifyView)
        signInVerifyView.anchor(top: scrollView.topAnchor,
                                leading: scrollView.leadingAnchor,
                                bottom: scrollView.safeBottomAnchor,
                                trailing: scrollView.trailingAnchor,
                                size: .init(
                                    width: 0,
                                            height: view.bounds.height))
        signInVerifyView.centerXInSuperview()
        signInVerifyView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        signInVerifyView.alpha = 0
        signInVerifyView.delegate = self
    }

    private func setUpFooterView() {
        scrollView.addSubview(useWithoutAccountButton)
        useWithoutAccountButton.anchor(top: signInView.bottomAnchor,
                                       leading: view.safeLeftAnchor,
                                       bottom: view.safeBottomAnchor,
                                       trailing: view.safeRightAnchor,
                                       padding: .init(top: 8, left: 20,
                                                      bottom: 16, right: 20))
    }
}
