#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

final class RuuviCloudApiFactoryURLSession: RuuviCloudApiFactory {
    func create(baseUrl: URL) -> RuuviCloudApi {
        RuuviCloudApiURLSession(baseUrl: baseUrl)
    }
}
