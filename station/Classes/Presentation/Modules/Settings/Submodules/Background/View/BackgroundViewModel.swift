import Foundation

class BackgroundViewModel: Identifiable {
    var id = UUID().uuidString
    var name = Observable<String?>()
    var isOn = Observable<Bool?>()
}

