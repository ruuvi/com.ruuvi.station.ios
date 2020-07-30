import Foundation

class ForegroundPresenter: NSObject, ForegroundModuleInput {
    weak var view: ForegroundViewInput!
    var router: ForegroundRouterInput!
    var settings: Settings!

    func configure() {
        let advertisement = ForegroundViewModel()
        advertisement.type = .advertisement
        advertisement.isOn.value = settings.isAdvertisementDaemonOn
        advertisement.interval.value = settings.advertisementDaemonIntervalMinutes
        advertisement.minValue.value = 0
        advertisement.maxValue.value = 3600
        bind(advertisement.isOn, fire: false) { (observer, isOn) in
            observer.settings.isAdvertisementDaemonOn = isOn ?? true
        }
        bind(advertisement.interval, fire: false) { observer, interval in
            observer.settings.advertisementDaemonIntervalMinutes = interval.bound
        }

        let webTags = ForegroundViewModel()
        webTags.type = .webTags
        webTags.isOn.value = settings.isWebTagDaemonOn
        webTags.interval.value = settings.webTagDaemonIntervalMinutes
        webTags.minValue.value = 15
        webTags.maxValue.value = 3600
        bind(webTags.isOn, fire: false) { observer, isOn in
            observer.settings.isWebTagDaemonOn = isOn.bound
        }
        bind(webTags.interval, fire: false) { observer, interval in
            observer.settings.webTagDaemonIntervalMinutes = interval.bound
        }

        view.viewModels = [advertisement, webTags]
    }
}

extension ForegroundPresenter: ForegroundViewOutput {

}
