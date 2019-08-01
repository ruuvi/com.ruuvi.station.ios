import Foundation
import Future

protocol WebTagService {
    
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError>
    func remove(webTag: WebTagRealm) -> Future<Bool,RUError>
    func update(name: String, of webTag: WebTagRealm) -> Future<Bool,RUError>
    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool,RUError>
    func clearLocation(of webTag: WebTagRealm) -> Future<Bool,RUError>
    
    func loadCurrentLocationData(from provider: WeatherProvider) -> Future<WebTagData,RUError>
    
    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T, provider: WeatherProvider, interval: TimeInterval, closure: @escaping (T, WebTagData?, RUError?) -> Void) -> WebTagServiceObservationToken
    
}

class WebTagServiceObservationToken {
    private let cancellationClosure: () -> Void
    
    init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }
    
    public func invalidate() {
        cancellationClosure()
    }
}

struct WebTagData {
    var celsius: Double?
    var humidity: Double?
    var pressure: Double?
    
    var fahrenheit: Double? {
        if let celsius = celsius {
            return (celsius * 9.0/5.0) + 32.0
        } else {
            return nil
        }
    }
}
