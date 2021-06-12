import Foundation
import RuuviOntology

class CurrentWebTagRefreshDataOperation: AsyncOperation {
    private var sensor: VirtualSensor
    private var provider: WeatherProvider
    private var weatherProviderService: WeatherProviderService
    private var alertService: AlertService
    private var webTagPersistence: WebTagPersistence!

    init(sensor: VirtualSensor,
         provider: WeatherProvider,
         weatherProviderService: WeatherProviderService,
         alertService: AlertService,
         webTagPersistence: WebTagPersistence) {
        self.sensor = sensor
        self.provider = provider
        self.weatherProviderService = weatherProviderService
        self.alertService = alertService
        self.webTagPersistence = webTagPersistence
    }

    override func main() {
        weatherProviderService.loadCurrentLocationData(from: provider).on(success: { [weak self] response in
            guard let sSelf = self else { return }
            sSelf.alertService.process(data: response.1, for: sSelf.sensor)
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
