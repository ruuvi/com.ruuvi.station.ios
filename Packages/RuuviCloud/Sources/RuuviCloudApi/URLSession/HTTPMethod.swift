#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviOntology
#endif
import Foundation

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
