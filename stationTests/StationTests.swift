@testable import station
import XCTest

class StationTests: XCTestCase {
    func testWebTagDaemonCrash() {
        NotificationCenter
            .default
            .post(name: .isWebTagDaemonOnDidChange,
                  object: self,
                  userInfo: nil)
        NotificationCenter
            .default
            .post(name: .WebTagDaemonIntervalDidChange,
                  object: self,
                  userInfo: nil)
    }
}
