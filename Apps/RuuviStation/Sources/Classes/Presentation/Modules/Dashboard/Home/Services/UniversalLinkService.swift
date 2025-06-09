import Foundation
import RuuviUser

protocol UniversalLinkServiceProtocol: AnyObject {
    var onUniversalLinkReceived: ((UniversalLinkType) -> Void)? { get set }
    
    func startObservingUniversalLinks()
    func stopObservingUniversalLinks()
    func processLink(_ userInfo: [AnyHashable: Any]) -> Bool
    func processUniversalLink(_ linkType: UniversalLinkType)
}

final class UniversalLinkService: UniversalLinkServiceProtocol {
    // MARK: - Dependencies
    private let ruuviUser: RuuviUser
    
    // MARK: - Properties
    var onUniversalLinkReceived: ((UniversalLinkType) -> Void)?
    
    // MARK: - Private Properties
    private var universalLinkObservationToken: NSObjectProtocol?
    
    // MARK: - Initialization
    init(ruuviUser: RuuviUser) {
        self.ruuviUser = ruuviUser
    }
    
    deinit {
        stopObservingUniversalLinks()
    }
    
    // MARK: - Public Methods
    func startObservingUniversalLinks() {
        universalLinkObservationToken = NotificationCenter.default.addObserver(
            forName: .DidOpenWithUniversalLink,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let userInfo = notification.userInfo {
                _ = self.processLink(userInfo)
            } else {
                // Handle case where user is already logged in
                self.handleAlreadyLoggedInCase()
            }
        }
    }
    
    func stopObservingUniversalLinks() {
        universalLinkObservationToken?.invalidate()
        universalLinkObservationToken = nil
    }
    
    func processLink(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let pathString = userInfo["path"] as? String else { return false }
        
        let linkType = parseLinkType(from: pathString)
        
        // Only process dashboard links if user is not authorized
        switch linkType {
        case .dashboard:
            if !ruuviUser.isAuthorized {
                onUniversalLinkReceived?(linkType)
                return true
            }
            return false
        case .verify:
            onUniversalLinkReceived?(linkType)
            return true
        }
    }
    
    func processUniversalLink(_ linkType: UniversalLinkType) {
        onUniversalLinkReceived?(linkType)
    }
    
    // MARK: - Private Methods
    private func parseLinkType(from path: String) -> UniversalLinkType {
//        if path.contains("dashboard") {
//            return .dashboard
//        } else if path.contains("sensor") {
//            // Extract sensor ID if present
//            let components = path.components(separatedBy: "/")
//            if let sensorIndex = components.firstIndex(of: "sensor"),
//               sensorIndex + 1 < components.count {
//                let sensorId = components[sensorIndex + 1]
//                return .sensor(id: sensorId)
//            }
//            return .sensor(id: "")
//        } else if path.contains("settings") {
//            return .settings
//        } else {
//            return .other(path: path)
//        }
        return .dashboard
    }
    
    private func handleAlreadyLoggedInCase() {
        // This could trigger a notification to show user is already logged in
        // For now, we'll just do nothing
    }
}
