import UIKit

struct TagSettingsViewModel {
    let background: Observable<UIImage> = Observable<UIImage>()
    let name: Observable<String> = Observable<String>()
    let humidityOffsetDate: Observable<Date?> = Observable<Date?>()
}
