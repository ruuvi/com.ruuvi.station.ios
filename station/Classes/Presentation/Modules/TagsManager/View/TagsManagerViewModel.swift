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
        title = sensor.name.isEmpty ? sensor.sensorId : sensor.name
        isOwner = sensor.isOwner
        let isOwnerTitle = isOwner ? "TagManagerCellViewModel.Owner".localized()
            : "TagManagerCellViewModel.Shared".localized()
        subTitle = sensor.sensorId + " (" + isOwnerTitle + ")"
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
