import Foundation

class RuuviTagReactorImpl: RuuviTagReactor {
    
    var sqlite: SQLiteContext!
    var realm: RealmContext!
    
    private lazy var rxSwift = RuuviTagSubjectRxSwift(sqlite: sqlite, realm: realm)
    #if canImport(Combine)
    @available(iOS 13, *)
    private lazy var combine = RuuviTagSubjectCombine(sqlite: sqlite, realm: realm)
    #endif
    
    func observe(_ block: @escaping (ReactorChange<RuuviTagSensor>) -> Void) -> RUObservationToken {
        #if canImport(Combine)
        if #available(iOS 13, *) {
            let cancellable = combine.insertSubject.sink { value in
                block(.insert(value))
            }
            return RUObservationToken {
                cancellable.cancel()
            }
        } else {
            let cancellable = rxSwift.insertSubject.subscribe(onNext: { value in
                block(.insert(value))
            })
            return RUObservationToken {
                cancellable.dispose()
            }
        }
        #else
        let cancellable = rxSwift.insertSubject.subscribe(onNext: { value in
            block(.insert(value))
        })
        return RUObservationToken {
            cancellable.dispose()
        }
        #endif
    }
    
}

