import Foundation

public protocol HasVirtualProvider {
    var provider: VirtualProvider { get }
}

public enum VirtualProvider: String, CaseIterable {
    case openWeatherMap
}
