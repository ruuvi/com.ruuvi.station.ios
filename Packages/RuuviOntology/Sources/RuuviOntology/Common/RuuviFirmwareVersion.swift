public enum RuuviFirmwareVersion: String {
    case v5
    case vC5
    case e0
    case f0
}

extension RuuviFirmwareVersion {
    public static func firmwareVersion(from version: Int) -> RuuviFirmwareVersion {
        switch version {
        case 5:
            return .v5
        case 0xC5:
            return .vC5
        case 224:
            return .e0
        case 240:
            return .f0
        default:
            return .v5
        }
    }
}
