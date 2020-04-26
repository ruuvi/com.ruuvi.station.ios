import Foundation

class KaltiotPickerPresenter {
    weak var view: KaltiotPickerViewInput!
    var output: KaltiotPickerModuleOutput!
    var router: KaltiotPickerRouterInput!
    var keychainService: KeychainService!
}
extension KaltiotPickerPresenter: KaltiotPickerViewOutput {
    func viewDidLoad() {
    }
}
extension KaltiotPickerPresenter: KaltiotPickerModuleInput {
    func configure(output: KaltiotPickerModuleOutput) {
        self.output = output
        #warning("dont forget remove this")
        keychainService.kaltiotApiKey = nil
    }

    func popViewController(animated: Bool) {
        router.popViewController(animated: animated)
    }
}
