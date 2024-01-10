import BTKit
import RuuviDaemon
import RuuviDFU

public struct RuuviFirmwareDependencies {
    public var background: BTBackground
    public var foreground: BTForeground
    public var propertiesDaemon: RuuviTagPropertiesDaemon
    public var ruuviDFU: RuuviDFU

    public init(
        background: BTBackground,
        foreground: BTForeground,
        propertiesDaemon: RuuviTagPropertiesDaemon,
        ruuviDFU: RuuviDFU
    ) {
        self.background = background
        self.foreground = foreground
        self.propertiesDaemon = propertiesDaemon
        self.ruuviDFU = ruuviDFU
    }
}

public final class RuuviFirmwareBuilder {
    public init() {}

    public func build(
        uuid: String,
        currentFirmware: String? = nil,
        dependencies: RuuviFirmwareDependencies
    ) -> RuuviFirmware {
        let presenter = FirmwarePresenter(
            uuid: uuid,
            currentFirmware: currentFirmware,
            background: dependencies.background,
            foreground: dependencies.foreground,
            propertiesDaemon: dependencies.propertiesDaemon,
            ruuviDFU: dependencies.ruuviDFU,
            firmwareRepository: FirmwareRepositoryImpl()
        )
        return presenter
    }
}
