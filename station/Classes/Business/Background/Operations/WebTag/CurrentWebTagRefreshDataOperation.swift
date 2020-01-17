import Foundation

class CurrentWebTagRefreshDataOperation: AsyncOperation {

    private var uuid: String
    private var provider: WeatherProvider
    private var weatherProviderService: WeatherProviderService
    private var alertService: AlertService
    private var webTagPersistence: WebTagPersistence!

    init(uuid: String,
         provider: WeatherProvider,
         weatherProviderService: WeatherProviderService,
         alertService: AlertService,
         webTagPersistence: WebTagPersistence) {
        self.uuid = uuid
        self.provider = provider
        self.weatherProviderService = weatherProviderService
        self.alertService = alertService
        self.webTagPersistence = webTagPersistence
    }

    override func main() {
        weatherProviderService.loadCurrentLocationData(from: provider).on(success: { [weak self] response in
            guard let sSelf = self else { return }
            sSelf.alertService.process(data: response.1, for: sSelf.uuid)
            let persist = sSelf.webTagPersistence.persist(currentLocation: response.0, data: response.1)
            persist.on(success: { [weak sSelf] _ in
                sSelf?.state = .finished
            }, failure: { [weak sSelf] error in
                print(error.localizedDescription)
                sSelf?.state = .finished
            })
        }, failure: { [weak self] error in
            print(error.localizedDescription)
            self?.state = .finished
        })
    }

}
