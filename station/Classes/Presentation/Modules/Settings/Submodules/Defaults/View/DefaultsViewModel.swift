import Foundation

class DefaultsViewModel: Identifiable {
    var id = UUID().uuidString
    
    var title: String?
    var boolean: Observable<Bool?> = Observable<Bool?>()
}
