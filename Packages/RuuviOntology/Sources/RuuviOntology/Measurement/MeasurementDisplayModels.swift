import Foundation

public struct MeasurementDisplayVariant: Hashable {
    public let type: MeasurementType
    public let temperatureUnit: TemperatureUnit?
    public let humidityUnit: HumidityUnit?
    public let pressureUnit: UnitPressure?

    public init(
        type: MeasurementType,
        temperatureUnit: TemperatureUnit? = nil,
        humidityUnit: HumidityUnit? = nil,
        pressureUnit: UnitPressure? = nil
    ) {
        self.type = type
        self.temperatureUnit = temperatureUnit
        self.humidityUnit = humidityUnit
        self.pressureUnit = pressureUnit
    }
}

public struct MeasurementDisplayEntry {
    public let variant: MeasurementDisplayVariant
    public var type: MeasurementType { variant.type }
    public var isVisible: Bool
    public var contexts: MeasurementDisplayContext

    public init(
        _ type: MeasurementType,
        temperatureUnit: TemperatureUnit? = nil,
        humidityUnit: HumidityUnit? = nil,
        pressureUnit: UnitPressure? = nil,
        visible: Bool = true,
        contexts: MeasurementDisplayContext = .all
    ) {
        self.variant = MeasurementDisplayVariant(
            type: type,
            temperatureUnit: temperatureUnit,
            humidityUnit: humidityUnit,
            pressureUnit: pressureUnit
        )
        self.isVisible = visible
        self.contexts = contexts
    }

    public func supports(_ context: MeasurementDisplayContext) -> Bool {
        contexts.contains(context)
    }
}

public struct MeasurementDisplayProfile {
    public let entries: [MeasurementDisplayEntry]

    public init(entries: [MeasurementDisplayEntry]) {
        self.entries = entries
    }

    public var orderedVisibleTypes: [MeasurementType] {
        orderedVisibleTypes(for: .indicator)
    }

    public var orderedVisibleVariants: [MeasurementDisplayVariant] {
        orderedVisibleVariants(for: .indicator)
    }

    public func entries(
        for context: MeasurementDisplayContext
    ) -> [MeasurementDisplayEntry] {
        entries.filter { $0.isVisible && $0.supports(context) }
    }

    public func orderedVisibleTypes(
        for context: MeasurementDisplayContext
    ) -> [MeasurementType] {
        orderedVisibleVariants(for: context).map { $0.type }
    }

    public func orderedVisibleVariants(
        for context: MeasurementDisplayContext
    ) -> [MeasurementDisplayVariant] {
        entries(for: context).map(\.variant)
    }

    public func entriesSupporting(
        _ context: MeasurementDisplayContext
    ) -> [MeasurementDisplayEntry] {
        entries.filter { $0.supports(context) }
    }
}

public struct MeasurementDisplayContext: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let none = MeasurementDisplayContext([])
    public static let indicator = MeasurementDisplayContext(rawValue: 1 << 0)
    public static let graph = MeasurementDisplayContext(rawValue: 1 << 1)
    public static let alert = MeasurementDisplayContext(rawValue: 1 << 2)

    public static let all: MeasurementDisplayContext = [.indicator, .graph, .alert]
}
