import Foundation
import Future
import RuuviCloud
import RuuviService
import RuuviUser
import RuuviPresenters
import RuuviDaemon
import FirebaseMessaging
import RuuviLocal
import WidgetKit

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
    var cloudNotificationService: RuuviServiceCloudNotification!
    var settings: RuuviLocalSettings!

    private var state: State = .enterEmail
    private var universalLinkObservationToken: NSObjectProtocol?
    private var viewModel: SignInViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }

    deinit {
        universalLinkObservationToken?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
// MARK: - SignInViewOutput
extension SignInPresenter: SignInViewOutput {
    func viewDidLoad() {
        syncViewModel()
        startObservingUniversalLinks()
        startObservingAppState()
    }

    func viewDidTapBack() {
        switch state {
        case .isSyncing:
            break
        case .enterVerificationCode:
            viewModel.showVerficationScreen.value = false
            state = .enterEmail
        case .enterEmail:
            router.popViewController(animated: true, completion: nil)
        }
    }

    func viewDidTapRequestCodeButton(for email: String?) {
        guard let email = email, isValidEmail(email) else {
            view.showInvalidEmailEntered()
            return
        }
        switch state {
        case .enterEmail:
            sendVerificationCode(for: email)
        default:
            return
        }
    }

    func viewDidTapEnterCodeManually(code: String) {
        verify(code)
    }

    func viewDidTapUseWithoutAccount() {
        output?.signIn(module: self,
                       didSelectUseWithoutAccount: nil)
    }
}

// MARK: - SignInModuleInput
extension SignInPresenter: SignInModuleInput {
    func configure(with state: SignInPresenter.State, output: SignInModuleOutput?) {
        self.output = output
        self.state = state
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss(completion: completion)
    }
}

// MARK: - Private
extension SignInPresenter {
    @objc private func syncViewModel() {
        viewModel = SignInViewModel()
        switch state {
        case .enterEmail:
            viewModel.showVerficationScreen.value = false
        case .enterVerificationCode(let code):
            viewModel.showVerficationScreen.value = true
            if let code = code {
                processCode(code)
            }
        case .isSyncing:
            return
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

    private func sendVerificationCode(for email: String) {
        activityPresenter.increment()
        ruuviCloud.requestCode(email: email)
            .on(success: { [weak self] email in
                guard let sSelf = self else { return }
                sSelf.ruuviUser.email = email
                sSelf.viewModel.showVerficationScreen.value = true
                sSelf.state = .enterVerificationCode(nil)
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func verify(_ code: String) {
        activityPresenter.increment(with: "SignIn.Sync.message".localized())
        ruuviCloud.validateCode(code: code)
            .on(success: { [weak self] result in
                guard let sSelf = self else { return }
                if sSelf.ruuviUser.email == result.email {
                    sSelf.ruuviUser.login(apiKey: result.apiKey)
                    sSelf.reloadWidgets()
                    sSelf.state = .isSyncing
                    sSelf.settings.isSyncing = true
                    sSelf.registerFCMToken()
                    sSelf.cloudSyncService.syncAllRecords().on(success: { [weak sSelf] _ in
                        guard let ssSelf = sSelf else { return }
                        ssSelf.activityPresenter.decrement()
                        ssSelf.cloudSyncDaemon.start()
                        ssSelf.output?.signIn(module: ssSelf, didSuccessfulyLogin: nil)
                        sSelf?.settings.isSyncing = false
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
                self?.view.showInvalidTokenEntered()
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
            activityPresenter.increment(with: "SignIn.Sync.message".localized())
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
        view.fromDeepLink = true
        viewModel.inputText.value = code
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750), execute: { [weak self] in
            self?.verify(code)
        })
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
    }

    private func registerFCMToken() {
        let sound = settings.alertSound
        let language = settings.language
        Messaging.messaging().token { [weak self] fcmToken, _ in
            self?.cloudNotificationService.set(token: fcmToken,
                                               name: UIDevice.modelName,
                                               data: nil,
                                               language: language,
                                               sound: sound)
        }
    }
}
