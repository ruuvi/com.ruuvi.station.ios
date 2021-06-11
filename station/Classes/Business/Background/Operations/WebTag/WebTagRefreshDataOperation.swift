import Foundation
import CoreLocation
import RuuviOntology

class WebTagRefreshDataOperation: AsyncOperation {
    private var sensor: VirtualSensor
    private var location: Location
    private var provider: WeatherProvider
    private var weatherProviderService: WeatherProviderService
    private var alertService: AlertService
    private var webTagPersistence: WebTagPersistence!

    init(sensor: VirtualSensor,
         location: Location,
         provider: WeatherProvider,
         weatherProviderService: WeatherProviderService,
         alertService: AlertService,
         webTagPersistence: WebTagPersistence) {
        self.sensor = sensor
        self.location = location
        self.provider = provider
        self.weatherProviderService = weatherProviderService
        self.alertService = alertService
        self.webTagPersistence = webTagPersistence
    }

    override func main() {
        weatherProviderService.loadData(coordinate: location.coordinate, provider: provider).on(success: {
            [weak self] data in
            guard let sSelf = self else { return }
            sSelf.alertService.process(data: data, for: sSelf.sensor)
            let persist = sSelf.webTagPersistence.persist(location: sSelf.location, data: data)
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
