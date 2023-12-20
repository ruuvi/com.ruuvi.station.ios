import Foundation

class Observable<ObservedType: OptionalType> {
    typealias Observer = (_ observable: Observable<ObservedType>, ObservedType.WrappedType?) -> Void

    private var observers: [Observer]

    var value: ObservedType.WrappedType? {
        didSet {
            notifyObservers(value)
        }
    }

    init(_ value: ObservedType? = nil) {
        self.value = value?.asOptional
        observers = []
    }

    func bind(observer: @escaping Observer) {
        observers.append(observer)
    }

    private func notifyObservers(_ value: ObservedType.WrappedType?) {
        observers.forEach { [unowned self] observer in
            observer(self, value)
        }
    }
}
