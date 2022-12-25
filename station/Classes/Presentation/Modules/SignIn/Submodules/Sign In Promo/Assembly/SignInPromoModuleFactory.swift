import Foundation

protocol SignInPromoModuleFactory: AnyObject {
    func create() -> SignInPromoViewController
}

class SignInPromoModuleFactoryImpl: SignInPromoModuleFactory {
    func create() -> SignInPromoViewController {

        let view = SignInPromoViewController()
        let router = SignInPromoRouter()
        let presenter = SignInPromoPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        view.output = presenter
        return view
    }
}
