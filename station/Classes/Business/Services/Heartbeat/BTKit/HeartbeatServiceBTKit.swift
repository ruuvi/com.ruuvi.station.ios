import Foundation
import Future
import BTKit
import RealmSwift

class HeartbeatServiceBTKit: HeartbeatService {
    
    var ruuviTagPersistence: RuuviTagPersistence!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var background: BTBackground!
    
    private var ruuviTags = [RuuviTagRealm]()
    private var ruuviTagsToken: NotificationToken?
    private var startTokens = [String: ObservationToken]()
    private var stopTokens = [String: ObservationToken]()
    
    func start() {
        let results = realmContext.main.objects(RuuviTagRealm.self).filter("keepConnection == true")
        ruuviTags = Array(results)
        ruuviTagsToken?.invalidate()
        ruuviTagsToken = results.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.ruuviTags = Array(ruuviTags)
                ruuviTags.forEach({ self?.startConnection(to: $0) })
            case .update(let ruuviTags, let deletions, let insertions, _):
                deletions.forEach({
                    if let ruuviTag = self?.ruuviTags[$0] {
                        self?.stopConnection(to: ruuviTag)
                    }
                })
                self?.ruuviTags = Array(ruuviTags)
                insertions.forEach({
                    if let ruuviTag = self?.ruuviTags[$0] {
                        self?.startConnection(to: ruuviTag)
                    }
                })
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
    
    func stop() {
        ruuviTagsToken?.invalidate()
        ruuviTags.forEach({ stopConnection(to: $0) })
        stopTokens.values.forEach({ $0.invalidate() } )
    }
    
    private func startConnection(to ruuviTag: RuuviTagRealm) {
        stopTokens[ruuviTag.uuid]?.invalidate()
        startTokens[ruuviTag.uuid] = background.connect(for: self, uuid: ruuviTag.uuid, connected: { [weak self] (observer, result) in
            switch result {
            case .already:
                print("already connected")
            case .just:
                print("just connected")
            case .disconnected:
                print("disconnected")
            case .failure(let error):
                self?.errorPresenter.present(error: error)
            }
        }, heartbeat: { [weak self] (observer, device) in
            print("heartbeat")
        }, disconnected: { [weak self] observer, result in
            switch result {
            case .just:
                print("just disconnected")
            case .already:
                print("already disconnected")
            case .failure(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }
    
    private func stopConnection(to ruuviTag: RuuviTagRealm) {
        startTokens[ruuviTag.uuid]?.invalidate()
        stopTokens[ruuviTag.uuid] = background.disconnect(for: self, uuid: ruuviTag.uuid, result: { [weak self] (observer, result) in
            switch result {
            case .just:
                print("just disconnected")
            case .already:
                print("already disconnected")
            case .failure(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }
    
    func startKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(keepConnection: true, of: ruuviTag)
    }
    
    func stopKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(keepConnection: false, of: ruuviTag)
    }
}
