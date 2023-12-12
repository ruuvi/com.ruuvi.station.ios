import UIKit

struct DefaultBackgroundModel {
    let id: Int
    let image: UIImage?
    let thumbnail: UIImage?
}

struct BackgroundSelectionViewModel {
    let background: Observable<UIImage?> = .init()
    let isUploadingBackground: Observable<Bool?> = .init()
    let uploadingBackgroundPercentage: Observable<Double?> = .init()
    let defaultImages: Observable<[DefaultBackgroundModel]?> = .init()
}
