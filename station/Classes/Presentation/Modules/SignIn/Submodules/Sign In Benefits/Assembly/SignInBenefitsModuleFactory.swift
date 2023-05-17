import Foundation

protocol SignInBenefitsModuleFactory: AnyObject {
    func create() -> SignInBenefitsViewController
}

class SignInPromoModuleFactoryImpl: SignInBenefitsModuleFactory {
    func create() -> SignInBenefitsViewController {

        let view = SignInBenefitsViewController()
        let router = SignInBenefitsRouter()
        let presenter = SignInBenefitsPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        view.output = presenter
        return view
    }
}
