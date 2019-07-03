import Foundation

class Observable<ObservedType> {
    typealias Observer = (_ observable: Observable<ObservedType>, ObservedType?) -> Void
    
    private var observers: [Observer]
    
    var value: ObservedType? {
        didSet {
            notifyObservers(value)
        }
    }
    
    init(_ value: ObservedType? = nil) {
        self.value = value
        observers = []
    }
    
    func bind(observer: @escaping Observer) {
        self.observers.append(observer)
    }
    
    private func notifyObservers(_ value: ObservedType?) {
        self.observers.forEach { [unowned self] (observer) in
            observer(self, value)
        }
    }
}
