import UIKit

struct DefaultBackgroundModel {
    let id: Int
    let image: UIImage?
    let thumbnail: UIImage?
}

struct BackgroundSelectionViewModel {
    let background: Observable<UIImage?> = Observable<UIImage?>()
    let isUploadingBackground: Observable<Bool?> = Observable<Bool?>()
    let uploadingBackgroundPercentage: Observable<Double?> = Observable<Double?>()
    let defaultImages: Observable<[DefaultBackgroundModel]?> = Observable<[DefaultBackgroundModel]?>()
}
