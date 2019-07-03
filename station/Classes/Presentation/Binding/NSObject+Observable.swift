import Foundation

public protocol OptionalType: ExpressibleByNilLiteral {
    associatedtype WrappedType
    var asOptional: WrappedType? { get }
}

extension Optional: OptionalType {
    public var asOptional: Wrapped? {
        return self
    }
}

extension NSObjectProtocol where Self: NSObject  {
    
    func bind<T: OptionalType>(_ observable: Observable<T>, block: @escaping (Self,T.WrappedType?) -> ()) {
        block(self, observable.value?.asOptional)
        observable.bind { [unowned self] observable, value  in
            DispatchQueue.main.async { [unowned self] in
                block(self, value?.asOptional)
            }
        }
    }
    
    func bind<T>(_ observable: Observable<T>, block: @escaping (Self,T?) -> ()) {
        block(self, observable.value)
        observable.bind { [unowned self] observable, value  in
            DispatchQueue.main.async { [unowned self] in
                block(self, value)
            }
        }
    }
}
