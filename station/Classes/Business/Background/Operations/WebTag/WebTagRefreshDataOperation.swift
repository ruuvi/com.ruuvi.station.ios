import Foundation
import CoreLocation

class WebTagRefreshDataOperation: AsyncOperation {

    private var uuid: String
    private var latitude: Double
    private var longitude: Double
    private var provider: WeatherProvider
    private var weatherProviderService: WeatherProviderService
    private var alertService: AlertService

    init(uuid: String,
         latitude: Double,
         longitude: Double,
         provider: WeatherProvider,
         weatherProviderService: WeatherProviderService,
         alertService: AlertService) {
        self.uuid = uuid
        self.latitude = latitude
        self.longitude = longitude
        self.provider = provider
        self.weatherProviderService = weatherProviderService
        self.alertService = alertService
    }

    override func main() {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let uuid = self.uuid
        weatherProviderService.loadData(coordinate: coordinate, provider: provider).on(success: { [weak self] data in
            self?.alertService.process(data: data, for: uuid)
            self?.state = .finished
        }, failure: { [weak self] error in
            print(error.localizedDescription)
            self?.state = .finished
        })
    }

}
