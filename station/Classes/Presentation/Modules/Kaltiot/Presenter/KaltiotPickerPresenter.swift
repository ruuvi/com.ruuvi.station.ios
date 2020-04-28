import Foundation

class KaltiotPickerPresenter {
    weak var view: KaltiotPickerViewInput!
    var output: KaltiotPickerModuleOutput!
    var router: KaltiotPickerRouterInput!
    var keychainService: KeychainService!
    var ruuviNetworkKaltiot: RuuviNetworkKaltiot!
    var errorPresenter: ErrorPresenter!

    private var page: Int = 0
    private var canLoadNextPage: Bool = true
}
// MARK: - KaltiotPickerViewOutput
extension KaltiotPickerPresenter: KaltiotPickerViewOutput {
    func viewDidLoad() {
        obtainBeacons()
    }
}
// MARK: - KaltiotPickerModuleInput
extension KaltiotPickerPresenter: KaltiotPickerModuleInput {
    func configure(output: KaltiotPickerModuleOutput) {
        self.output = output
    }

    func popViewController(animated: Bool) {
        router.popViewController(animated: animated)
    }
}
// MARK: - Private
extension KaltiotPickerPresenter {
    private func obtainBeacons() {
        if canLoadNextPage {
            let op = ruuviNetworkKaltiot.beacons(page: page)
            op.on(success: { (beacons) in
                debugPrint(beacons)
            }, failure: {[weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: nil)
        }
    }
}
