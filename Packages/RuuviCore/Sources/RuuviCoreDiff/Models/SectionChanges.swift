import Foundation

public class SectionChanges {
    public var insertsInts = [Int]()
    public var deletesInts = [Int]()
    public var updates = CellChanges()

    public var inserts: IndexSet {
        IndexSet(insertsInts)
    }

    public var deletes: IndexSet {
        IndexSet(deletesInts)
    }

    public init(inserts: [Int] = [], deletes: [Int] = [], updates: CellChanges = CellChanges()) {
        insertsInts = inserts
        deletesInts = deletes
        self.updates = updates
    }
}
