import Foundation

class SectionChanges {
    var insertsInts = [Int]()
    var deletesInts = [Int]()
    var updates = CellChanges()

    var inserts: IndexSet {
        return IndexSet(insertsInts)
    }
    var deletes: IndexSet {
        return IndexSet(deletesInts)
    }

    init(inserts: [Int] = [], deletes: [Int] = [], updates: CellChanges = CellChanges()) {
        self.insertsInts = inserts
        self.deletesInts = deletes
        self.updates = updates
    }
}
