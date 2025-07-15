public enum RuuviFirmwareVersion: String {
    case v5
    case vC5
    case e1
    case v6
}

extension RuuviFirmwareVersion {
    public static func firmwareVersion(from version: Int) -> RuuviFirmwareVersion {
        switch version {
        case 5:
            return .v5
        case 0xC5:
            return .vC5
        case 225:
            return .e1
        case 6:
            return .v6
        default:
            return .v5
        }
    }
}
