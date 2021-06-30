import Foundation

public class SectionChanges {
    public var insertsInts = [Int]()
    public var deletesInts = [Int]()
    public var updates = CellChanges()

    public var inserts: IndexSet {
        return IndexSet(insertsInts)
    }
    public var deletes: IndexSet {
        return IndexSet(deletesInts)
    }

    public init(inserts: [Int] = [], deletes: [Int] = [], updates: CellChanges = CellChanges()) {
        self.insertsInts = inserts
        self.deletesInts = deletes
        self.updates = updates
    }
}
