import UIKit

// TODO: Remove this when legacy menu is removed
public enum CardsMenuMode {
    case legacy
    case modern
}

public enum CardsMenuType: String, CaseIterable {
    case measurement
    case graph
    case alerts
    case settings
}

// TODO: Remove this when legacy menu is removed
public enum CardsLegacyMenuType: String, CaseIterable {
    case alerts
    case measurementGraph
    case settings
}
