import Foundation

public enum AlertType: CaseIterable {
    case temperature(lower: Double, upper: Double) // celsius
    case humidity(lower: Humidity, upper: Humidity)
    case relativeHumidity(lower: Double, upper: Double) // fraction of one
    case pressure(lower: Double, upper: Double) // hPa
    case signal(lower: Double, upper: Double) // dB
    case carbonDioxide(lower: Double, upper: Double) // ppm
    case pMatter1(lower: Double, upper: Double) // µg/m³
    case pMatter2_5(lower: Double, upper: Double) // µg/m³
    case pMatter4(lower: Double, upper: Double) // µg/m³
    case pMatter10(lower: Double, upper: Double) // µg/m³
    case voc(lower: Double, upper: Double) // VOC Index
    case nox(lower: Double, upper: Double) // NOx Index
    case sound(lower: Double, upper: Double) // dB
    case luminosity(lower: Double, upper: Double) // lx
    case connection
    case cloudConnection(unseenDuration: Double)
    case movement(last: Int)

    public static var allCases: [AlertType] {
        [
            .temperature(lower: 0, upper: 0),
            .relativeHumidity(lower: 0, upper: 0),
            .humidity(
                lower: Humidity.zeroAbsolute,
                upper: Humidity.zeroAbsolute
            ),
            .pressure(lower: 0, upper: 0),
            .signal(lower: 0, upper: 0),
            .carbonDioxide(lower: 0, upper: 0),
            .pMatter1(lower: 0, upper: 0),
            .pMatter2_5(lower: 0, upper: 0),
            .pMatter4(lower: 0, upper: 0),
            .pMatter10(lower: 0, upper: 0),
            .voc(lower: 0, upper: 0),
            .nox(lower: 0, upper: 0),
            .sound(lower: 0, upper: 0),
            .luminosity(lower: 0, upper: 0),
            .connection,
            .cloudConnection(unseenDuration: 0),
            .movement(last: 0),
        ]
    }
}

public enum AlertState {
    case registered
    case empty
    case firing
}
