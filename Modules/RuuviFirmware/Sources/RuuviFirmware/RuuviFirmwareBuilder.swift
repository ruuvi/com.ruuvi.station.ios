import BTKit
import RuuviDFU

public struct RuuviFirmwareDependencies {
    public var background: BTBackground
    public var foreground: BTForeground
    public var ruuviDFU: RuuviDFU
    public var firmwareRepository: FirmwareRepository
}

public final class RuuviFirmwareBuilder {
    public init() {}

    public func build(
        uuid: String,
        currentFirmware: String? = nil,
        dependencies: RuuviFirmwareDependencies = .default
    ) -> RuuviFirmware {
        let presenter = FirmwarePresenter(
            uuid: uuid,
            currentFirmware: currentFirmware,
            background: dependencies.background,
            foreground: dependencies.foreground,
            ruuviDFU: dependencies.ruuviDFU,
            firmwareRepository: dependencies.firmwareRepository
        )
        return presenter
    }
}

public extension RuuviFirmwareDependencies {
    static var `default`: Self {
        RuuviFirmwareDependencies(
            background: BTKit.background,
            foreground: BTKit.foreground,
            ruuviDFU: RuuviDFUImpl.shared,
            firmwareRepository: FirmwareRepositoryImpl()
        )
    }
}
