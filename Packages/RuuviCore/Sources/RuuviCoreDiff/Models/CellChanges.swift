import Foundation

public class CellChanges {
    public var inserts = [IndexPath]()
    public var deletes = [IndexPath]()
    public var reloads = [IndexPath]()

    public init(inserts: [IndexPath] = [], deletes: [IndexPath] = [], reloads: [IndexPath] = []) {
        self.inserts = inserts
        self.deletes = deletes
        self.reloads = reloads
    }
}
