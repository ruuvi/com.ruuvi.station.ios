import UIKit

struct TagSettingsViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let name: Observable<String?> = Observable<String?>()
    let uuid: Observable<String?> = Observable<String?>()
    let mac: Observable<String?> = Observable<String?>()
    let humidity: Observable<Double?> = Observable<Double?>()
    let humidityOffset: Observable<Double?> = Observable<Double?>()
    let humidityOffsetDate: Observable<Date?> = Observable<Date?>()
    let voltage: Observable<Double?> = Observable<Double?>()
    let accelerationX: Observable<Double?> = Observable<Double?>()
    let accelerationY: Observable<Double?> = Observable<Double?>()
    let accelerationZ: Observable<Double?> = Observable<Double?>()
}
