import Foundation

class RuuviTagReactorImpl: RuuviTagReactor {
    
    var rxSwift: RuuviTagReactorRxSwift!
    #if canImport(Combine)
    @available(iOS 13, *)
    lazy var combine = RuuviTagReactorCombine()
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

