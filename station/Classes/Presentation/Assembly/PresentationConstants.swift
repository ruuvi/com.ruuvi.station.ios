import Foundation

struct Presentation: Codable {
    var FeedbackEmail: String
    var FeedbackSubject: String
}

final class PresentationConstants {
    static let presentationPath = Bundle.main.path(forResource: "Presentation", ofType: "plist")!
    static let xml = FileManager.default.contents(atPath: presentationPath)!
    static let presentationPlist = try! PropertyListDecoder().decode(Presentation.self, from: xml)

    static let feedbackEmail = presentationPlist.FeedbackEmail
    static let feedbackSubject = presentationPlist.FeedbackSubject
}
