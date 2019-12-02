import Foundation
import RealmSwift
import CoreLocation

class WebTagDaemonImpl: BackgroundWorker, WebTagDaemon {

    var webTagService: WebTagService!
    var settings: Settings!
    var webTagPersistence: WebTagPersistence!

    private var realm: Realm!
    private var token: NotificationToken?
    private var wsTokens = [RUObservationToken]()
    private var webTags: Results<WebTagRealm>?
    private var isOnToken: NSObjectProtocol?
    private var intervalToken: NSObjectProtocol?

    private var pullInterval: TimeInterval {
        return TimeInterval(settings.webTagDaemonIntervalMinutes * 60)
    }

    override init() {
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
        intervalToken = NotificationCenter
            .default
            .addObserver(forName: .WebTagDaemonIntervalDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.perform(#selector(WebTagDaemonImpl.restartPulling(fire:)),
                            on: sSelf.thread,
                            with: false,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue])
        })
    }

    deinit {
        wsTokens.forEach({ $0.invalidate() })
        wsTokens.removeAll()
        token?.invalidate()
        if let isOnToken = isOnToken {
            NotificationCenter.default.removeObserver(isOnToken)
        }
    }

    func start() {
        start { [weak self] in
            self?.realm = try! Realm()

            self?.token = self?.realm.objects(WebTagRealm.self).observe({ [weak self] (change) in
                switch change {
                case .initial(let webTags):
                    self?.webTags = webTags
                    self?.restartPulling(fire: true)
                case .update(let webTags, _, _, _):
                    self?.webTags = webTags
                    self?.restartPulling(fire: true)
                case .error(let error):
                    print(error.localizedDescription)
                }
            })
        }
    }

    func stop() {
        wsTokens.forEach({ $0.invalidate() })
        wsTokens.removeAll()
        token?.invalidate()
        stopWork()
    }

    @objc private func restartPulling(fire: Bool) {

        wsTokens.forEach({ $0.invalidate() })
        wsTokens.removeAll()

        guard let webTags = webTags else { return }

        let currentLocationWebTags = webTags.filter({ $0.location == nil })

        for provider in WeatherProvider.allCases {
            if currentLocationWebTags.contains(where: { $0.provider == provider }) {
                wsTokens.append(webTagService.observeCurrentLocationData(self,
                                                                         provider: provider,
                                                                         interval: pullInterval,
                                                                         fire: fire,
                                                                         closure: { (observer, data, location, error) in
                    if let data = data, let location = location {
                        observer.webTagPersistence.persist(currentLocation: location, data: data)
                    } else if let error = error {
                        DispatchQueue.main.async {
                            NotificationCenter
                                .default
                                .post(name: .WebTagDaemonDidFail,
                                      object: nil,
                                      userInfo: [WebTagDaemonDidFailKey.error: error])
                        }
                    }
                }))
            }
        }

        let locationWebTags = webTags.filter({ $0.location != nil })
        for webTag in locationWebTags {
            guard let location = webTag.location else { return }
            let locationLocation = location.location
            let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            wsTokens.append(webTagService.observeData(self,
                                                      coordinate: coordinate,
                                                      provider: webTag.provider,
                                                      interval: pullInterval,
                                                      fire: fire,
                                                      closure: { (observer, data, error) in
                if let data = data {
                    observer.webTagPersistence.persist(location: locationLocation, data: data)
                } else if let error = error {
                    DispatchQueue.main.async {
                        NotificationCenter
                            .default
                            .post(name: .WebTagDaemonDidFail,
                                  object: nil,
                                  userInfo: [WebTagDaemonDidFailKey.error: error])
                    }
                }
            }))
        }
    }

}
