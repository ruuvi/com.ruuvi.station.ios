import Foundation
import Future
import CoreLocation
import RuuviOntology

public protocol RuuviLocationService {
    func search(
        query: String
    ) -> Future<[Location], RuuviLocationError>

    func reverseGeocode(
        coordinate: CLLocationCoordinate2D
    ) -> Future<[Location], RuuviLocationError>
}
