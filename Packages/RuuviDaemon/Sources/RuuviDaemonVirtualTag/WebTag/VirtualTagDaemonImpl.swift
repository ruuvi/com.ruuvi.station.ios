import Foundation
import CoreLocation
import RuuviLocal
import RuuviOntology
import RuuviVirtual
import RuuviNotifier
import RuuviDaemon
#if canImport(RuuviDaemonOperation)
import RuuviDaemonOperation
#endif

public final class VirtualTagDaemonImpl: RuuviDaemonWorker, VirtualTagDaemon {
    private let virtualService: VirtualService
    private let settings: RuuviLocalSettings
    private let virtualPersistence: VirtualPersistence
    private let alertService: RuuviNotifier
    private let virtualReactor: VirtualReactor

    private var token: VirtualReactorToken?
    private var wsTokens = [VirtualToken]()
    private var virtualTags = [AnyVirtualTagSensor]()
    private var isOnToken: NSObjectProtocol?
    private var intervalToken: NSObjectProtocol?

    private var pullInterval: TimeInterval {
        return TimeInterval(settings.webTagDaemonIntervalMinutes * 60)
    }

    deinit {
        autoreleasepool {
            wsTokens.forEach({ $0.invalidate() })
            wsTokens.removeAll()
            token?.invalidate()
            if let isOnToken = isOnToken {
                NotificationCenter.default.removeObserver(isOnToken)
            }
            if let intervalToken = intervalToken {
                NotificationCenter.default.removeObserver(intervalToken)
            }
        }
    }

    public init(
        virtualService: VirtualService,
        settings: RuuviLocalSettings,
        virtualPersistence: VirtualPersistence,
        alertService: RuuviNotifier,
        virtualReactor: VirtualReactor
    ) {
        self.virtualService = virtualService
        self.settings = settings
        self.virtualPersistence = virtualPersistence
        self.alertService = alertService
        self.virtualReactor = virtualReactor
        super.init()
        isOnToken = NotificationCenter
            .default
            .addObserver(forName: .isWebTagDaemonOnDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            guard let sSelf = self else { return }
            if sSelf.settings.isWebTagDaemonOn {
                sSelf.start()
            } else {
                sSelf.stop()
            }
        })
    }

    public func start() {
        start { [weak self] in
            self?.stopDaemon()
            self?.token?.invalidate()
            self?.token = self?.virtualReactor.observe({ [weak self] change in
                switch change {
                case .initial(let sensors):
                    self?.virtualTags = sensors
                    self?.restartPulling(fire: true)
                case .insert(let sensor):
                    self?.virtualTags.append(sensor)
                    self?.restartPulling(fire: true)
                case .delete(let sensor):
                    self?.virtualTags.removeAll(where: { $0.id == sensor.id })
                    self?.restartPulling(fire: true)
                case .update(let sensor):
                    if let index = self?.virtualTags.firstIndex(of: sensor) {
                        self?.virtualTags[index] = sensor
                    }
                    self?.restartPulling(fire: true)
                case .error(let error):
                    print(error.localizedDescription)
                }
            })

            self?.intervalToken = NotificationCenter
                .default
                .addObserver(forName: .WebTagDaemonIntervalDidChange,
                             object: nil,
                             queue: .main,
                             using: { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.perform(#selector(VirtualTagDaemonImpl.restartPulling(fire:)),
                                on: sSelf.thread,
                                with: false,
                                waitUntilDone: false,
                                modes: [RunLoop.Mode.default.rawValue])
            })
        }
    }

    public func stop() {
        perform(#selector(VirtualTagDaemonImpl.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
        stopWork()
    }

    @objc private func stopDaemon() {
        autoreleasepool {
            wsTokens.forEach({ $0.invalidate() })
            wsTokens.removeAll()
            token?.invalidate()
            token = nil
            if let intervalToken = intervalToken {
                NotificationCenter.default.removeObserver(intervalToken)
            }
        }
    }

    @objc private func restartPulling(fire: Bool) {
        wsTokens.forEach({ $0.invalidate() })
        wsTokens.removeAll()

        restartPullingCurrentLocation(virtualTags: virtualTags, fire: fire)
        restartPullingFixedLocations(virtualTags: virtualTags, fire: fire)
    }

    private func restartPullingFixedLocations(
        virtualTags: [AnyVirtualTagSensor],
        fire: Bool
    ) {
        let virtualTagsWithLocation = virtualTags.filter({ $0.loc != nil })
        for virtualTag in virtualTagsWithLocation {
            guard let location = virtualTag.loc else { return }
            wsTokens.append(
                virtualService.observeData(
                    self,
                    coordinate: location.coordinate,
                    provider: virtualTag.provider,
                    interval: pullInterval,
                    fire: fire,
                    closure: { (observer, data, error) in
                        if let data = data {
                            observer.virtualPersistence.persist(
                                location: location,
                                data: data
                            )
                            observer.alertService.process(
                                data: data,
                                for: virtualTag
                            )
                        } else if let error = error {
                            observer.post(error: error)
                        }
                    }
                )
            )
        }
    }

    private func restartPullingCurrentLocation(
        virtualTags: [AnyVirtualTagSensor],
        fire: Bool
    ) {
        let virtualTagsWithoutLocation = virtualTags.filter({ $0.loc == nil })
        for provider in VirtualProvider.allCases {
            // swiftlint:disable:next for_where
            if virtualTagsWithoutLocation.contains(where: { $0.provider == provider }) {
                wsTokens.append(
                    virtualService.observeCurrentLocationData(
                        self,
                        provider: provider,
                        interval: pullInterval,
                        fire: fire,
                        closure: { (observer, data, location, error) in
                            if let data = data, let location = location {
                                observer.virtualPersistence.persist(
                                    currentLocation: location,
                                    data: data
                                )
                                virtualTagsWithoutLocation.forEach({
                                    observer.alertService.process(
                                        data: data,
                                        for: $0
                                    )
                                })
                            } else if let error = error {
                                observer.post(error: error)
                            }
                        }
                    )
                )
            }
        }
    }

    private func post(error: Error) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .WebTagDaemonDidFail,
                      object: nil,
                      userInfo: [WebTagDaemonDidFailKey.error: error])
        }
    }
}
