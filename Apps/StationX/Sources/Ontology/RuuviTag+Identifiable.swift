import BTKit

extension RuuviTag: Identifiable {
    public var id: String {
        uuid
    }
}
