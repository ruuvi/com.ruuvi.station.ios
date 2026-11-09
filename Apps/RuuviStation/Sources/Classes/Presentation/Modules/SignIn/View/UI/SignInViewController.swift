// swiftlint:disable file_length
import Foundation
import RuuviLocalization
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
        let button = UIBarButtonItem(
            image: RuuviAsset.chevronBack.image,
            style: .plain,
            target: self,
            action: #selector(handleBackButtonTap)
        )
        if #unavailable(iOS 26.0) {
            button.tintColor = .white
        }
        return button
    }()

    private lazy var bgLayer: UIImageView = {
        let iv = UIImageView(image: RuuviAsset.commonBgLayer.image)
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    private var sideInsetSwitch: RuuviVerticalBarConstraintSwitch?

    private lazy var signInView = SignInView()
    private lazy var signInVerifyView = SignInVerifyView()

    private lazy var useWithoutAccountButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        button.setTitle(
            RuuviLocalization.useWithoutAccount,
            for: .normal
        )
        button.titleLabel?.font = UIFont.mulish(.semiBoldItalic, size: 14)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.addTarget(
            self,
            action: #selector(handleUseWithoutAccountTap),
            for: .touchUpInside
        )
        button.underline()
        return button
    }()

    /// The email page: from the content top to 16pt below `useWithoutAccountButton`.
    private lazy var emailPageGuide = UILayoutGuide()
    /// Only the page on screen defines the scroll content height (one of these is active).
    private var emailPageContentBottom: NSLayoutConstraint?
    private var verifyPageContentBottom: NSLayoutConstraint?
    private var isShowingVerificationPage = false
    /// The keyboard's end frame from its last notification, in screen coordinates; nil while hidden.
    private var keyboardFrame: CGRect?

    // ---------------------
    private var shouldAvoidVerifying: Bool = false
}

// MARK: - VIEW LIFE CYCLE

extension SignInViewController {
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        sideInsetSwitch?.update(for: traitCollection)
        // The window's class: UIKit can give this sheet a compact width even on a full-screen iPad.
        let layoutClass = signInLayoutClass
        signInView.applyLayout(layoutClass)
        signInVerifyView.applyLayout(layoutClass)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The pages and their fields are laid out by the scroll view, after this call; lay them out
        // now so the keyboard check reads this pass's frames and content size.
        scrollView.layoutIfNeeded()
        updateKeyboardInset(revealingFocus: false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        observeLayoutChanges()
        localize()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.makeTransparentForDarkBackground()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.resetStyleToDefault()
    }
}

private extension SignInViewController {
    @objc func handleBackButtonTap() {
        output.viewDidTapBack()
    }

    @objc func handleUseWithoutAccountTap() {
        output.viewDidTapUseWithoutAccount()
    }

    private func bindViewModel() {
        guard isViewLoaded
        else {
            return
        }

        view.bind(viewModel.showVerficationScreen) { [weak self] _, verificationPage in
            let showVerificationPage = GlobalHelpers.getBool(from: verificationPage)
            self?.showContentPage(verification: showVerificationPage)
            self?.signInVerifyView.alpha = showVerificationPage ? 1 : 0
            if showVerificationPage {
                self?.signInVerifyView.activate()
            }
            self?.signInView.alpha = showVerificationPage ? 0 : 1
            self?.useWithoutAccountButton.alpha = showVerificationPage ? 0 : 1
        }

        signInView.bind(viewModel.inputText) { view, text in
            if view.enteredEmail() != text {
                view.populateEmail(from: text)
            }
        }

        signInVerifyView.bind(viewModel.inputText) { view, text in
            view.populate(from: text)
        }
    }
}

extension SignInViewController: SignInViewInput {
    func localize() {
        // No op.
    }

    func showEmailsAreDifferent(requestedEmail: String, validatedEmail: String) {
        let message = RuuviLocalization.SignIn.EmailMismatch.Alert.message(
            requestedEmail,
            validatedEmail,
            requestedEmail
        )
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

    func showUnexpectedHTTPStatusCodeError() {
        let message = RuuviLocalization.RuuviCloudApiError.unexpectedHTTPStatusCodeShouldRetry
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.ok,
            style: .cancel,
            handler: { [weak self] _ in
                self?.output.viewDidTapOkFromUnexpectedHTTPStatusCodeError()
        }))
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
    func didFinishTypingCode(code: String, sender _: SignInVerifyView) {
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
        emailPageContentBottom?.isActive = true
    }

    private func setUpBase() {
        view.backgroundColor = RuuviColor.primary.color

        view.addSubview(bgLayer)
        bgLayer.fillSuperview()

        view.addSubview(scrollView)
        scrollView.anchor(
            top: view.safeTopAnchor,
            leading: nil,
            bottom: view.bottomAnchor,
            trailing: nil
        )
        // iPhone Duo: keep the content clear of the vertical bar / status bar on the side.
        sideInsetSwitch = RuuviVerticalBarConstraintSwitch(
            standard: [
                scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                scrollView.widthAnchor.constraint(equalTo: view.widthAnchor),
            ],
            verticalBar: [
                scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            ]
        )
    }

    private func setUpNavBarView() {
        navigationItem.leftBarButtonItem = backButton
    }

    private func setUpSignInView() {
        scrollView.addSubview(signInView)
        signInView.anchor(
            top: scrollView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil
        )
        signInView.centerXInSuperview()
        signInView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        signInView.alpha = 1
        signInView.delegate = self
    }

    private func setUpSignInVerifyView() {
        scrollView.addSubview(signInVerifyView)
        signInVerifyView.anchor(
            top: scrollView.topAnchor,
            leading: scrollView.leadingAnchor,
            bottom: nil,
            trailing: scrollView.trailingAnchor
        )
        signInVerifyView.centerXInSuperview()
        signInVerifyView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        // The page fills the visible safe height, as before. In a short window the beaver's space
        // shrinks first (the beaver is cropped); the page grows, and scrolls, only when the title and
        // code field need more room.
        let visibleHeight = scrollView.safeAreaLayoutGuide.heightAnchor
        let fillVisibleHeight = signInVerifyView.heightAnchor.constraint(equalTo: visibleHeight)
        fillVisibleHeight.priority = SignInVerifyView.fillVisibleHeightPriority
        NSLayoutConstraint.activate([
            signInVerifyView.heightAnchor.constraint(greaterThanOrEqualTo: visibleHeight),
            fillVisibleHeight,
        ])
        verifyPageContentBottom = scrollView.contentLayoutGuide.bottomAnchor.constraint(
            equalTo: signInVerifyView.bottomAnchor
        )
        signInVerifyView.alpha = 0
        signInVerifyView.delegate = self
    }

    private func setUpFooterView() {
        scrollView.addSubview(useWithoutAccountButton)
        useWithoutAccountButton.anchor(
            top: signInView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: 8,
                left: 20,
                bottom: 0,
                right: 20
            )
        )

        // The email page fills the visible safe height, as before: the button sits 16pt above the
        // safe bottom and the email field stays centered. It grows, and scrolls, only when a short
        // window cannot fit it. The low priority lets the content's own minimum height win.
        scrollView.addLayoutGuide(emailPageGuide)
        let visibleHeight = scrollView.safeAreaLayoutGuide.heightAnchor
        let fillVisibleHeight = emailPageGuide.heightAnchor.constraint(equalTo: visibleHeight)
        fillVisibleHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            emailPageGuide.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            emailPageGuide.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            emailPageGuide.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            emailPageGuide.bottomAnchor.constraint(equalTo: useWithoutAccountButton.bottomAnchor, constant: 16),
            emailPageGuide.heightAnchor.constraint(greaterThanOrEqualTo: visibleHeight),
            fillVisibleHeight,
        ])
        emailPageContentBottom = scrollView.contentLayoutGuide.bottomAnchor.constraint(
            equalTo: emailPageGuide.bottomAnchor
        )
    }
}

// MARK: - LAYOUT CLASS, PAGES AND KEYBOARD

extension SignInViewController {
    private func observeLayoutChanges() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges(RuuviLayoutClass.traitsAffectingLayoutClass) {
                (controller: SignInViewController, _: UITraitCollection) in
                controller.view.setNeedsLayout()
            }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    /// Lets the page on screen alone define the scroll content height and starts it at the top.
    private func showContentPage(verification: Bool) {
        guard verification != isShowingVerificationPage else { return }
        isShowingVerificationPage = verification
        let active = verification ? verifyPageContentBottom : emailPageContentBottom
        let inactive = verification ? emailPageContentBottom : verifyPageContentBottom
        inactive?.isActive = false
        active?.isActive = true
        guard view.window != nil else { return }
        view.layoutIfNeeded()
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top),
            animated: false
        )
        updateKeyboardInset(revealingFocus: true)
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        keyboardFrame = frame?.cgRectValue
        guard view.window != nil else { return }
        view.layoutIfNeeded()
        updateKeyboardInset(revealingFocus: true)
    }

    @objc private func keyboardWillHide(_: Notification) {
        keyboardFrame = nil
        updateKeyboardInset(revealingFocus: false)
    }

    /// How far the docked keyboard covers the scroll view, measured up from its bottom edge.
    /// A floating or undocked keyboard, which ends above that edge, counts as not covering it.
    private func keyboardOverlap() -> CGFloat {
        guard let keyboardFrame,
              let screen = view.window?.windowScene?.screen
        else {
            return 0
        }
        let keyboard = view.convert(keyboardFrame, from: screen.coordinateSpace)
        let scrollFrame = scrollView.frame
        guard keyboard.maxY >= scrollFrame.maxY - 1,
              keyboard.minY < scrollFrame.maxY,
              keyboard.minX < scrollFrame.maxX,
              keyboard.maxX > scrollFrame.minX
        else {
            return 0
        }
        return scrollFrame.maxY - max(keyboard.minY, scrollFrame.minY)
    }

    /// Keeps the email field and Request code button, or the code field, reachable above the
    /// docked keyboard. The scroll view gets a bottom inset only while the keyboard covers them
    /// with the page scrolled to its top, so where they stay clear of the keyboard (iPhone)
    /// nothing changes. `revealingFocus` also scrolls them into view. Cheap when nothing changed,
    /// so it runs on every layout pass (live resizing) too.
    private func updateKeyboardInset(revealingFocus: Bool) {
        let overlap = keyboardOverlap()
        let focusView = isShowingVerificationPage
            ? signInVerifyView.keyboardAvoidanceView
            : signInView.keyboardAvoidanceView
        // In content coordinates.
        let focus = focusView.convert(focusView.bounds, to: scrollView)
        let topOffset = -scrollView.adjustedContentInset.top
        let height = scrollView.bounds.height
        let isCovered = overlap > 0 && focus.maxY > topOffset + height - overlap
        let inset = isCovered ? overlap : 0
        let insetChanged = scrollView.contentInset.bottom != inset
        if insetChanged {
            scrollView.contentInset.bottom = inset
            scrollView.verticalScrollIndicatorInsets.bottom = inset
        }
        guard insetChanged || (revealingFocus && isCovered) else { return }

        var offset = scrollView.contentOffset.y
        if revealingFocus, isCovered {
            let margin: CGFloat = 16
            let isVisible = focus.minY - margin >= offset - topOffset
                && focus.maxY + margin <= offset + height - overlap
            if !isVisible {
                // The focus bottom just above the keyboard, but never its top out of view.
                let revealing = focus.maxY + margin - (height - overlap)
                offset = max(min(revealing, focus.minY - margin + topOffset), topOffset)
            }
        }
        // Never past the end of the content, e.g. once the keyboard inset is gone.
        let contentHeight = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom
        offset = min(offset, max(topOffset, contentHeight - height))
        if offset != scrollView.contentOffset.y {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: offset), animated: true)
        }
    }
}

// swiftlint:enable file_length
