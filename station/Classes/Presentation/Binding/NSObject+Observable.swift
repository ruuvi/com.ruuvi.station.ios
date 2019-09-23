import Foundation

extension NSObjectProtocol where Self: NSObject  {
    
    func bind<T: OptionalType>(_ observable: Observable<T>, block: @escaping (Self,T.WrappedType?) -> ()) {
        block(self, observable.value)
        observable.bind { [weak self] _, value  in
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else { return }
                block(sSelf, value)
            }
        }
    }
    
}
