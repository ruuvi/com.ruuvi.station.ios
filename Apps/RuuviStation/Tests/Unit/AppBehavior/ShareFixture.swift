import Foundation
import RuuviCloud
import RuuviOntology
import RuuviService
@testable import station

@MainActor final class ShareFixture {
    let measurements = MeasurementFixture()
    let service = ShareOwnershipSpy()
    let pool = AppPoolSpy()
    let reactor = AppTestReactor()
    let view = ShareViewSpy()
    let router = ShareRouterSpy()
    let activity = AccountActivitySpy()
    let errors = OffsetErrorSpy()
    let alerts = GraphAlertSpy()
    var sensor: RuuviTagSensor
    var presenter: SharePresenter!
    init(canShare: Bool = true) {
        sensor = measurements.sensor.with(canShare: canShare)
        presenter = SharePresenter()
        presenter.view = view
        presenter.router = router
        presenter.activityPresenter = activity
        presenter.errorPresenter = errors
        presenter.alertPresenter = alerts
        presenter.ruuviOwnershipService = service
        presenter.ruuviReactor = reactor
        presenter.ruuviPool = pool
    }
    func configure() { presenter.configure(sensor: sensor) }
    func sendSensors(_ sensors: [AnyRuuviTagSensor]) {
        Array(reactor.sensors.values).forEach { $0(.initial(sensors)) }
    }
}

final class ShareViewSpy: ShareViewInput {
    var viewModel: ShareViewModel!
    var reloads = 0
    var cleared = 0
    var invalidEmails = 0
    var shared = 0
    var invited = 0
    func reloadTableView() { reloads += 1 }
    func clearInput() { cleared += 1 }
    func showInvalidEmail() { invalidEmails += 1 }
    func showSuccessfullyShared() { shared += 1 }
    func showSuccessfullyInvited() { invited += 1 }
}
final class ShareRouterSpy: ShareRouterInput {
    var dismissals = 0
    func dismiss(completion: (() -> Void)?) { dismissals += 1; completion?() }
}

@MainActor final class ShareOwnershipSpy: RuuviServiceOwnership {
    var ownerChecks = [String]()
    var ownerResult: (String?, String?) = (nil, nil)
    var ownerFailure: RuuviServiceError?
    var beforeOwner: (() async -> Void)?
    var claims = [AnyRuuviTagSensor]()
    var unclaims = [(AnyRuuviTagSensor, Bool)]()
    var contests = [(AnyRuuviTagSensor, String)]()
    var beforeClaim: (() async -> Void)?
    var beforeContest: (() async -> Void)?
    var shares = [(String, String)]()
    var unshares = [(String, String?)]()
    var loaded = [String]()
    var updates = [AnyRuuviTagSensor]()
    var result = ShareSensorResponse(invited: false)
    var shareable = Set<AnyShareableSensor>()
    var shareFailure: RuuviServiceError?
    var loadFailure: RuuviServiceError?
    var updateFailure: RuuviServiceError?
    var beforeShare: (() async -> Void)?
    var allowAdds = false
    var additions = [(AnyRuuviTagSensor, AnyRuuviTagSensorRecord?)]()
    var addFailure: RuuviServiceError?
    var beforeAdd: (() async -> Void)?
    var beforeLoad: (() async -> Void)?
    var beforeUpdate: (() async -> Void)?
    func share(macId: MACIdentifier, with email: String) async throws(RuuviServiceError) -> ShareSensorResponse {
        shares.append((macId.value, email))
        await beforeShare?()
        if let shareFailure { throw shareFailure }
        return result
    }
    func unshare(macId: MACIdentifier, with email: String?) async throws(RuuviServiceError) -> MACIdentifier {
        unshares.append((macId.value, email))
        if let shareFailure { throw shareFailure }
        return macId
    }
    func loadShared(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Set<AnyShareableSensor> {
        loaded.append(sensor.id)
        let captured = shareable
        await beforeLoad?()
        if let loadFailure { throw loadFailure }
        return captured
    }
    func updateShareable(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Bool {
        updates.append(sensor.any)
        await beforeUpdate?()
        if let updateFailure { throw updateFailure }
        return true
    }
    func add(sensor: RuuviTagSensor, record: RuuviTagSensorRecord?) async throws(RuuviServiceError) -> AnyRuuviTagSensor
    {
        guard allowAdds else { throw .failedToParseNetworkResponse }
        additions.append((sensor.any, record?.any))
        await beforeAdd?()
        if let addFailure { throw addFailure }
        return sensor.any
    }
    func remove(sensor: RuuviTagSensor, removeCloudHistory: Bool) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        throw .failedToParseNetworkResponse
    }
    func claim(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        claims.append(sensor.any)
        await beforeClaim?()
        if let shareFailure { throw shareFailure }
        return sensor.with(isOwner: true).any
    }
    func contest(sensor: RuuviTagSensor, secret: String) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        contests.append((sensor.any, secret))
        await beforeContest?()
        if let shareFailure { throw shareFailure }
        return sensor.with(isOwner: true).any
    }
    func unclaim(sensor: RuuviTagSensor, removeCloudHistory: Bool) async throws(RuuviServiceError) -> AnyRuuviTagSensor
    {
        unclaims.append((sensor.any, removeCloudHistory))
        await beforeClaim?()
        if let shareFailure { throw shareFailure }
        return sensor.with(isOwner: false).any
    }
    func checkOwner(macId: MACIdentifier) async throws(RuuviServiceError) -> (String?, String?) {
        ownerChecks.append(macId.value)
        await beforeOwner?()
        if let ownerFailure { throw ownerFailure }
        return ownerResult
    }
}
