import UIKit
import RuuviUser

protocol RuuviOnboardPagesViewControllerOutput: AnyObject {
    func ruuviOnboardPages(_ viewController: RuuviOnboardPagesViewController, didFinish sender: Any?)
    func ruuviOnboardCloudSignIn(_ viewController: RuuviOnboardPagesViewController, didPresentSignIn sender: Any?)
}

final class RuuviOnboardPagesViewController: UIViewController {
    var output: RuuviOnboardPagesViewControllerOutput?
    var ruuviUser: RuuviUser?

    init() {
        pageController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        backgroundImageView = Self.makeBackgroundImageView()
        overlayImageView = Self.makeOverlayImageView()
        logoImageView = Self.makeLogoImageView()
        super.init(nibName: nil, bundle: nil)
        pageController.dataSource = self
        pageController.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        styleViews()
        layoutViews()
        setupPages()
        startObservingUserSignedInNotification()
    }

    private func startObservingUserSignedInNotification() {
        NotificationCenter
            .default
            .addObserver(forName: .RuuviUserDidAuthorized,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.navigateToStartPage()
            })
    }

    private func navigateToStartPage() {
        pageController.goToNextPage()
    }

    private let pageController: UIPageViewController
    private var controllers = [UIViewController]()
    private let backgroundImageView: UIImageView
    private let overlayImageView: UIImageView
    private let logoImageView: UIImageView

    private func setupViews() {
        view.addSubview(backgroundImageView)
        view.addSubview(overlayImageView)
        view.addSubview(logoImageView)
    }

    private func styleViews() {
        backgroundImageView.image = UIImage.named("background", for: Self.self)
        overlayImageView.image = UIImage.named("overlay", for: Self.self)
        logoImageView.image = UIImage.named("ruuvi_logo", for: Self.self)
    }

    private func layoutViews() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayImageView.topAnchor.constraint(equalTo: view.topAnchor),
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            logoImageView.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func setupPages() {
        addChild(pageController)
        view.addSubview(pageController.view)

        let views = ["pageController": pageController.view] as [String: AnyObject]
        view.addConstraints(NSLayoutConstraint.constraints(
                                withVisualFormat: "H:|[pageController]|",
                                options: [],
                                metrics: nil,
                                views: views))
        view.addConstraints(NSLayoutConstraint.constraints(
                                withVisualFormat: "V:|[pageController]|",
                                options: [],
                                metrics: nil,
                                views: views))

        let welcome = RuuviOnboardImageTitleViewController(
            imageName: "welcome_friend",
            titleKey: "RuuviOnboard.Welcome.title",
            isWelcomScreen: true
        )
        controllers.append(welcome)

        let measure = RuuviOnboardImageTitleViewController(
            imageName: "measure_data",
            titleKey: "RuuviOnboard.Measure.title"
        )
        controllers.append(measure)

        let access = RuuviOnboardImageTitleViewController(
            imageName: "access_data",
            titleKey: "RuuviOnboard.Access.title"
        )
        controllers.append(access)

        let alerts = RuuviOnboardImageTitleViewController(
            imageName: "set_alerts",
            titleKey: "RuuviOnboard.Alerts.title"
        )
        controllers.append(alerts)

        let cloud = RuuviOnboardCloudSigninViewController()
        cloud.delegate = self
        cloud.ruuviUser = ruuviUser
        controllers.append(cloud)

        let start = RuuviOnboardStartViewController()
        start.delegate = self
        controllers.append(start)

        pageController.setViewControllers([controllers[0]], direction: .forward, animated: false)
    }

    private func showSkipConfirmationDialog() {
        let title = "RuuviOnboard.Cloud.Skip.title".localized(for: Self.self)
        let message = "RuuviOnboard.Cloud.Benefits.message"
            .localized(for: Self.self)
            .replacingOccurrences(of: "\\n\\n",
                                  with: "\n\n")
        let skipActionTitle = "RuuviOnboard.Cloud.Skip.Yes.title".localized(for: Self.self).uppercased()
        let goBackActionTitle = "RuuviOnboard.Cloud.Skip.GoBack.title".localized(for: Self.self).uppercased()
        let skipAction = UIAlertAction(title: skipActionTitle,
                                       style: .default,
                                       handler: nil)
        let goBackAction = UIAlertAction(title: goBackActionTitle,
                                         style: .default,
                                         handler: { [weak self] _ in
            guard let sSelf = self else {
                return
            }
            sSelf.output?.ruuviOnboardCloudSignIn(sSelf, didPresentSignIn: nil)
        })
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.setMessageAlignment(.left)
        alert.addAction(goBackAction)
        alert.addAction(skipAction)
        present(alert, animated: true)
    }
}

extension RuuviOnboardPagesViewController: RuuviOnboardStartViewControllerDelegate {
    func ruuviOnboardStart(_ viewController: RuuviOnboardStartViewController, didFinish sender: Any?) {
        output?.ruuviOnboardPages(self, didFinish: nil)
    }
}

extension RuuviOnboardPagesViewController: RuuviOnboardCloudSigninViewControllerDelegate {
    func ruuviOnboardShowSignIn(_ viewController: RuuviOnboardCloudSigninViewController, didShowSignIn sender: Any?) {
        output?.ruuviOnboardCloudSignIn(self, didPresentSignIn: nil)
    }
}

extension RuuviOnboardPagesViewController: UIPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        if let index = controllers.firstIndex(of: viewController) {
            if index > 0 {
                return controllers[index - 1]
            } else {
                return nil
            }
        }

        return nil
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        if let index = controllers.firstIndex(of: viewController) {
            if index < controllers.count - 1 {
                return controllers[index + 1]
            } else {
                return nil
            }
        }

        return nil
    }
}

extension RuuviOnboardPagesViewController: UIPageViewControllerDelegate {
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return controllers.count
    }

    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        if let currentVC = pageViewController.viewControllers?.first,
           let index = controllers.firstIndex(of: currentVC) {
            return index
        } else {
            return 0
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first,
              let index = controllers.firstIndex(of: currentVC) else { return }
        if index == controllers.count - 1 {
            guard let ruuviUser = ruuviUser, !ruuviUser.isAuthorized else {
                return
            }
            showSkipConfirmationDialog()
        }
    }
}

// MARK: - Factory
extension RuuviOnboardPagesViewController {
    private static func makeBackgroundImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }

    private static func makeOverlayImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }

    private static func makeLogoImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
}

extension UIPageViewController {
    func goToNextPage() {
       guard let currentViewController = self.viewControllers?.first else {
           return
       }
       guard let nextViewController = dataSource?.pageViewController(self,
                                                                     viewControllerAfter: currentViewController) else {
           return
       }
       setViewControllers([nextViewController], direction: .forward, animated: false, completion: nil)
    }
}
