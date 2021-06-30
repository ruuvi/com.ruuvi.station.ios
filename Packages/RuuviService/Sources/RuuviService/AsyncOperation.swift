import Foundation

open class AsyncOperation: Operation {

  public enum State: String {
      case ready, executing, finished

    fileprivate var keyPath: String {
      return "is" + rawValue.capitalized
    }
  }

  open var state = State.ready {
    willSet {
      willChangeValue(forKey: newValue.keyPath)
      willChangeValue(forKey: state.keyPath)
    }
    didSet {
      didChangeValue(forKey: oldValue.keyPath)
      didChangeValue(forKey: state.keyPath)
    }
  }
}

extension AsyncOperation {
  override open var isReady: Bool {
    return super.isReady && state == .ready
  }

  override open var isExecuting: Bool {
    return state == .executing
  }

  override open var isFinished: Bool {
    return state == .finished
  }

  override open var isAsynchronous: Bool {
    return true
  }

  override open func start() {
    if isCancelled {
      state = .finished
      return
    }
    main()
    state = .executing
  }

  override open func cancel() {
    state = .finished
  }

}
