import Foundation

struct TagsManagerViewModel {
    var title: Observable<String?> = .init()
    var items: Observable<[TagManagerCellViewModel]?> = .init([])
    var actions: Observable<[TagManagerActionType]?> = .init([])
}

struct TagManagerCellViewModel {
    let imageUrl: URL?
    let title: String?
    let subTitle: String?
    let isOwner: Bool

    init(sensor: UserApiUserSensor) {
        imageUrl = URL(string: sensor.pictureUrl)
        title = sensor.sensorId
        isOwner = sensor.isOwner
        subTitle = isOwner ? "Owner" : "Shared tag"
    }
}

enum TagManagerActionType: Int, CaseIterable {
    case addMissingTag = 0

    var title: String {
        switch self {
        case .addMissingTag:
            return "TagManagerActionCellViewModel.AddMissingTag.Title".localized()
        }
    }
}
