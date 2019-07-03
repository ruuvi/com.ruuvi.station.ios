import Foundation

extension NSObjectProtocol where Self: NSObject  {
    
    func bind<T: OptionalType>(_ observable: Observable<T>, block: @escaping (Self,T.WrappedType?) -> ()) {
        block(self, observable.value)
        observable.bind { [unowned self] observable, value  in
            DispatchQueue.main.async { [unowned self] in
                block(self, value)
            }
        }
    }
    
}
