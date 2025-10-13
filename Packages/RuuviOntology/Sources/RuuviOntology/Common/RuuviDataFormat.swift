public enum RuuviDataFormat: String {
    case v5
    case vC5
    case e1
    case v6
}

extension RuuviDataFormat {
    public static func dataFormat(from version: Int) -> RuuviDataFormat {
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
