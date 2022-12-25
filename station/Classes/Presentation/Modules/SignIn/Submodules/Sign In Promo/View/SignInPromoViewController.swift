import Foundation
import UIKit

class SignInPromoViewController: UIViewController, SignInPromoViewInput {

    // Configuration
    var output: SignInPromoViewOutput?

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

    private lazy var signInPromoView = SignInPromoView()

    private lazy var useWithoutAccountButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        button.setTitle("use_without_account".localized(),
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

}

// MARK: - VIEW LIFE CYCLE
extension SignInPromoViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
    }
}

extension SignInPromoViewController {
    @objc fileprivate func handleBackButtonTap() {
        output?.viewDidTapLetsDoIt()
    }

    @objc fileprivate func handleUseWithoutAccountTap() {
        output?.viewDidTapUseWithoutAccount()
    }
}

extension SignInPromoViewController {
    func localize() {
        // No op.
    }
}

extension SignInPromoViewController: SignInPromoViewDelegate {
    func didTapLetsDoButton(sender: SignInPromoView) {
        output?.viewDidTapLetsDoIt()
    }
}

// MARK: - PRIVATE UI SETUP
extension SignInPromoViewController {
    private func setUpUI() {
        setUpNavBarView()
        setUpBase()
        setUpSignInPromoView()
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

    private func setUpSignInPromoView() {
        scrollView.addSubview(signInPromoView)
        signInPromoView.anchor(top: scrollView.topAnchor,
                         leading: nil,
                         bottom: nil,
                         trailing: nil)
        signInPromoView.centerXInSuperview()
        signInPromoView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        signInPromoView.delegate = self
    }

    private func setUpFooterView() {
        scrollView.addSubview(useWithoutAccountButton)
        useWithoutAccountButton.anchor(top: signInPromoView.bottomAnchor,
                                       leading: view.safeLeftAnchor,
                                       bottom: view.safeBottomAnchor,
                                       trailing: view.safeRightAnchor,
                                       padding: .init(top: 0, left: 20,
                                                      bottom: 8, right: 20))
    }
}
