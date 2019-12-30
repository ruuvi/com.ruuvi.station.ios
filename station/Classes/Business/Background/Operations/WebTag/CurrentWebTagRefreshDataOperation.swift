import Foundation

class CurrentWebTagRefreshDataOperation: AsyncOperation {

    private var uuid: String
    private var provider: WeatherProvider
    private var weatherProviderService: WeatherProviderService
    private var alertService: AlertService

    init(uuid: String,
         provider: WeatherProvider,
         weatherProviderService: WeatherProviderService,
         alertService: AlertService) {
        self.uuid = uuid
        self.provider = provider
        self.weatherProviderService = weatherProviderService
        self.alertService = alertService
    }

    override func main() {
        let uuid = self.uuid
        weatherProviderService.loadCurrentLocationData(from: provider).on(success: { [weak self] response in
            self?.alertService.process(data: response.1, for: uuid)
            self?.state = .finished
        }, failure: { [weak self] error in
            print(error.localizedDescription)
            self?.state = .finished
        })
    }

}
