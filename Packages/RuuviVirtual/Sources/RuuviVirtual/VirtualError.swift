import Foundation

public enum VirtualReactorError: Error {
    case virtualPersistence(VirtualPersistenceError)
}

public enum VirtualPersistenceError: Error {
    case persistence(Error)
    case failedToFindVirtualTag
}

public enum VirtualRepositoryError: Error {
    case virtualPersistence(VirtualPersistenceError)
}

public enum VirtualStorageError: Error {
    case virtualPersistence(VirtualPersistenceError)
}
