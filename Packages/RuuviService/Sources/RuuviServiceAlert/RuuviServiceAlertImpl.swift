import Foundation
import Future
import RuuviOntology
import RuuviCloud

final class RuuviServiceAlertImpl: RuuviServiceAlert {
    private let cloud: RuuviCloud

    init(
        cloud: RuuviCloud
    ) {
        self.cloud = cloud
    }
}
