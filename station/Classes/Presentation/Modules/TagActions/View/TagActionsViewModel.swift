import Foundation

class TagActionsViewModel: Identifiable {
    var id: String { get { uuid }}
    var uuid: String
    
    init(uuid: String) {
        self.uuid = uuid
    }
}
