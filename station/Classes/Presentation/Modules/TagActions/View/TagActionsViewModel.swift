import Foundation

class TagActionsViewModel: Identifiable {
    var id: String { get { uuid }}
    var uuid: String
    
    var isSyncEnabled = Observable<Bool?>(false)
    
    init(uuid: String) {
        self.uuid = uuid
    }
}
