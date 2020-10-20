import XCTest
import Quick
import Nimble
import Future

@testable import station
class RuuviNetworkWhereOSSpec: QuickSpec {
    override func spec() {
        let network = RuuviNetworkWhereOSURLSession()
        describe("Load data or predefined MAC") {
            context("when data is on backend") {
                it("must parse data") {
                    waitUntil(timeout: 10) { done in
                        let op: Future<[RuuviTagProtocol],RUError> = network.load(mac: "c0:4d:b1:4a:b6:35")
                        op.on(success: { ruuviTags in
                            print(ruuviTags)
                            done()
                        }, failure: { error in
                            done()
                        })
                    }
                }
            }
        }
    }

}
