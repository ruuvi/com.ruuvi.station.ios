import Foundation
import RuuviLocalization
import UIKit

class MyRuuviAccountViewController: UIViewController {
    var output: MyRuuviAccountViewOutput!

    @IBOutlet weak var supportLinkTextView: RuuviLinkTextView!
    @IBOutlet var loggedInLabel: UILabel!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var signoutButton: UIButton!
    @IBOutlet var deleteAccountButton: UIButton!

    private lazy var communicationTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        return label
    }()

    private lazy var subscriptionTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        return label
    }()

    private lazy var communicationSubtitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private lazy var communicationSwitchView: RuuviSwitchView = {
        let view = RuuviSwitchView(delegate: self)
        view.toggleState(with: false)
        return view
    }()

    private lazy var subscriptionRow: UIStackView = {
        subscriptionTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        subscriptionTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        communicationSwitchView.setContentHuggingPriority(.required, for: .horizontal)
        communicationSwitchView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stackView = UIStackView(arrangedSubviews: [
            subscriptionTitleLabel,
            communicationSwitchView,
        ])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()

    private lazy var communicationSectionStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            communicationTitleLabel,
            communicationSubtitleLabel,
            subscriptionRow,
        ])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .fill
        return stackView
    }()

    var viewModel: MyRuuviAccountViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        styleViews()
        setUpSupportLinkView()
        setUpCommunicationSection()
        setUpVerticalLayout()
        configureViews()
        localize()
        output.viewDidLoad()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
        loggedInLabel.textColor = RuuviColor.textColor.color
        usernameLabel.textColor = RuuviColor.textColor.color
        communicationTitleLabel.textColor = RuuviColor.textColor.color
        subscriptionTitleLabel.textColor = RuuviColor.textColor.color
        communicationSubtitleLabel.textColor = RuuviColor.textColor.color
        deleteAccountButton.backgroundColor = RuuviColor.orangeColor.color
        signoutButton.backgroundColor = RuuviColor.tintColor.color

        loggedInLabel.font = .ruuviHeadline()
        usernameLabel.font = .ruuviBody()
        communicationTitleLabel.font = .ruuviHeadline()
        subscriptionTitleLabel.font = .ruuviHeadline()
        communicationSubtitleLabel.font = .ruuviBody()
        deleteAccountButton.titleLabel?.font = .ruuviButtonMedium()
        signoutButton.titleLabel?.font = .ruuviButtonMedium()
    }

    private func setUpCommunicationSection() {
        guard let accountDetailsStackView = loggedInLabel.superview as? UIStackView
        else {
            return
        }

        supportLinkTextView.removeFromSuperview()
        supportLinkTextView.textContainerInset = .zero
        supportLinkTextView.textContainer.lineFragmentPadding = 0
        supportLinkTextView.constraints
            .first { $0.firstAttribute == .height }?
            .constant = 44

        loggedInLabel.constraints
            .first { $0.firstAttribute == .height }?
            .constant = 22

        let topSeparator = makeSeparatorView()
        let bottomSeparator = makeSeparatorView()

        accountDetailsStackView.alignment = .fill
        accountDetailsStackView.spacing = 6
        accountDetailsStackView.addArrangedSubview(supportLinkTextView)
        accountDetailsStackView.addArrangedSubview(topSeparator)
        accountDetailsStackView.addArrangedSubview(communicationSectionStackView)
        accountDetailsStackView.addArrangedSubview(bottomSeparator)

        accountDetailsStackView.setCustomSpacing(8, after: usernameLabel)
        accountDetailsStackView.setCustomSpacing(12, after: supportLinkTextView)
        accountDetailsStackView.setCustomSpacing(16, after: topSeparator)
        accountDetailsStackView.setCustomSpacing(12, after: communicationSectionStackView)

        communicationSectionStackView.spacing = 10
        communicationSectionStackView.setCustomSpacing(
            16,
            after: communicationSubtitleLabel
        )

        communicationSectionStackView.translatesAutoresizingMaskIntoConstraints = false
        communicationSectionStackView.widthAnchor.constraint(
            equalTo: accountDetailsStackView.widthAnchor
        ).isActive = true
    }

    private func makeSeparatorView() -> UIView {
        let separator = UIView()
        separator.backgroundColor = RuuviColor.textColor.color.withAlphaComponent(0.25)
        separator.heightAnchor.constraint(
            equalToConstant: 1 / UIScreen.main.scale
        ).isActive = true
        return separator
    }

    private func setUpVerticalLayout() {
        guard let buttonsStackView = deleteAccountButton.superview else {
            return
        }

        // Allow the middle of the page to expand and keep the actions
        // consistently above the bottom safe area.
        view.constraints
            .filter { constraint in
                (constraint.firstItem as? UIView) === buttonsStackView &&
                    constraint.firstAttribute == .top
            }
            .forEach { $0.isActive = false }

        NSLayoutConstraint.activate([
            buttonsStackView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -24
            ),
        ])
    }

    private func setUpSupportLinkView() {
        supportLinkTextView.linkDelegate = self
        supportLinkTextView.setUpComponents(
            textColor: RuuviColor.textColor.color.withAlphaComponent(0.8),
            fullTextString: RuuviLocalization.myAccountChangeEmail,
            linkString: RuuviLocalization.myAccountChangeEmailLinkMarkup,
            link: RuuviLocalization.myAccountChangeEmailLink,
            fontSize: 15
        )
    }

    // MARK: - Button actions

    @IBAction func backButtonTouchUpInside(_: Any) {
        output.viewDidTriggerClose()
    }

    @IBAction func deleteButtonTouchUpInside(_: Any) {
        output.viewDidTapDeleteButton()
    }

    @IBAction func signoutButtonTouchUpInside(_: Any) {
        output.viewDidTapSignoutButton()
    }
}

extension MyRuuviAccountViewController: RuuviLinkTextViewDelegate {
    func didTapLink(url: String) {
        output.viewDidTriggerSupport(with: url)
    }
}

extension MyRuuviAccountViewController: RuuviSwitchViewDelegate {
    func didChangeSwitchState(sender _: RuuviSwitchView, didToggle isOn: Bool) {
        output.viewDidChangeMarketingPreference(isEnabled: isOn)
    }
}

extension MyRuuviAccountViewController: MyRuuviAccountViewInput {
    func localize() {}

    func viewDidShowAccountDeletionConfirmation() {
        let message = RuuviLocalization.MyRuuvi.Settings.DeleteAccount.Confirmation.message
        let alertVC = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

extension MyRuuviAccountViewController {
    private func bindViewModel() {
        guard let viewModel, isViewLoaded
        else {
            return
        }
        usernameLabel.bind(viewModel.username) { label, username in
            label.text = username
        }
        loggedInLabel.bind(viewModel.username) { label, username in
            label.text = username == nil ? nil : RuuviLocalization.Menu.LoggedIn.title
        }
        communicationSectionStackView.bind(viewModel.showMarketingPreference) { view, isVisible in
            view.isHidden = !(isVisible ?? false)
        }
        communicationSwitchView.bind(viewModel.marketingPreference) { view, isEnabled in
            view.toggleState(with: isEnabled)
        }
    }

    private func configureViews() {
        self.title = RuuviLocalization.Menu.Label.MyRuuviAccount.text
        navigationItem.leftBarButtonItem?.image = RuuviAsset.dismissModalIcon.image
        communicationTitleLabel.text = RuuviLocalization.communicationChannels
        communicationSubtitleLabel.text = RuuviLocalization.communicationChannelsDescription
        subscriptionTitleLabel.text = RuuviLocalization.newsletterSubscription
        deleteAccountButton.setTitle(RuuviLocalization.MyRuuvi.Settings.DeleteAccount.title, for: .normal)
        deleteAccountButton.setTitle(RuuviLocalization.MyRuuvi.Settings.DeleteAccount.title, for: .normal)
        signoutButton.setTitle(RuuviLocalization.Menu.SignOut.text, for: .normal)
        signoutButton.setTitle(RuuviLocalization.Menu.SignOut.text, for: .highlighted)
    }
}
