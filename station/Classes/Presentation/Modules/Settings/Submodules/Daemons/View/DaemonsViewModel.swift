import Foundation
import Combine
import SwiftUI

class DaemonsViewModel: Identifiable {
    var id = UUID().uuidString
    var type: DaemonType = .advertisement
    var isOn: Observable<Bool?> = Observable<Bool?>(true)
    var interval: Observable<Int?> = Observable<Int?>(1)
    
    var title: String {
        switch type {
        case .advertisement:
            return "DaemonsRow.advertisement.title".localized()
        case .connection:
            return "DaemonsRow.connection.title".localized()
        }
    }
    
    var section: String {
        switch type {
        case .advertisement:
            return "DaemonsRow.advertisement.section".localized()
        case .connection:
            return "DaemonsRow.connection.section".localized()
        }
    }
    
}
