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
    
    func observe<T: OptionalType>(for observable: Observable<T>, with: @escaping (Self,T.WrappedType?) -> ()) {
        observable.bind { [unowned self] observable, value  in
            DispatchQueue.main.async { [unowned self] in
                with(self, value?.asOptional)
            }
        }
    }
    
    func observe<T>(for observable: Observable<T>, with: @escaping (Self,T?) -> ()) {
        observable.bind { [unowned self] observable, value  in
            DispatchQueue.main.async { [unowned self] in
                with(self, value)
            }
        }
    }
}
