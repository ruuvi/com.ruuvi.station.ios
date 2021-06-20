import Foundation
import Future
import CoreLocation
import RuuviOntology

public protocol VirtualPersistence {
    func readAll() -> Future<[AnyVirtualTagSensor], VirtualPersistenceError>
    func readOne(_ id: String) -> Future<AnyVirtualTagSensor, VirtualPersistenceError>
    func deleteAllRecords(
        _ ruuviTagId: String,
        before date: Date
    ) -> Future<Bool, VirtualPersistenceError>

    func persist(
        provider: VirtualProvider,
        name: String
    ) -> Future<VirtualProvider, VirtualPersistenceError>
    func persist(
        provider: VirtualProvider,
        location: Location,
        name: String
    ) -> Future<VirtualProvider, VirtualPersistenceError>
    func remove(sensor: VirtualSensor) -> Future<Bool, VirtualPersistenceError>
    func update(
        name: String,
        of sensor: VirtualSensor
    ) -> Future<Bool, VirtualPersistenceError>
    func update(
        location: Location,
        of webTag: WebTagRealm,
        name: String
    ) -> Future<Bool, VirtualPersistenceError>
    func clearLocation(
        of webTag: WebTagRealm,
        name: String
    ) -> Future<Bool, VirtualPersistenceError>

    @discardableResult
    func persist(
        currentLocation: Location,
        data: VirtualData
    ) -> Future<VirtualData, VirtualPersistenceError>
    @discardableResult
    func persist(
        location: Location,
        data: VirtualData
    ) -> Future<VirtualData, VirtualPersistenceError>
}
