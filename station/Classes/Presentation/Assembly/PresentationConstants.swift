//
//  PresentationConstants.swift
//  station
//
//  Created by Iiro Alhonen on 07.12.21.
//  Copyright © 2021 Ruuvi Innovations Oy. BSD-3-Clause.
//

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
