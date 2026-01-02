public struct RuuviAlertConstants {
    public struct Temperature {
        public static let lowerBound = -40.0 // Celsius
        public static let upperBound = 85.0  // Celsius

        public static let customLowerBound = -55.0 // Celsius
        public static let customUpperBound = 150.0  // Celsius
    }

    public struct RelativeHumidity {
        public static let lowerBound = 0.0   // Percentage (%)
        public static let upperBound = 100.0 // Percentage (%)
    }

    public struct AbsoluteHumidity {
        public static let lowerBound = 0.0   // g/m3
        public static let upperBound = 650.0  // g/m3
    }

    public struct DewPoint {
        public static let lowerBound = -55.0 // celsius
        public static let upperBound = 150.0  // celsius
    }

    public struct Pressure {
        public static let lowerBound = 500.0  // hPa
        public static let upperBound = 1155.0 // hPa
    }

    public struct Signal {
        public static let lowerBound = -105.0 // dBm
        public static let upperBound = 0.0    // dBm
    }

    public struct AQI {
        public static let lowerBound = 0.0  // %
        public static let upperBound = 100.0 // %
    }

    public struct CarbonDioxide {
        public static let lowerBound = 350.0  // ppm
        public static let upperBound = 2500.0 // ppm
    }

    public struct ParticulateMatter {
        public static let lowerBound = 0.0   // µg/m³
        public static let upperBound = 250.0 // µg/m³
    }

    public struct VOC {
        public static let lowerBound = 0.0   // VOC Index
        public static let upperBound = 500.0 // VOC Index
    }

    public struct NOX {
        public static let lowerBound = 0.0   // NOx Index
        public static let upperBound = 500.0 // NOx Index
    }

    public struct Sound {
        public static let lowerBound = 0.0    // dB
        public static let upperBound = 127.0  // dB
    }

    public struct Luminosity {
        public static let lowerBound = 0.0     // lx
        public static let upperBound = 144284.0 // lx
    }

    public struct BatteryVoltage {
        public static let lowerBound = 1.8 // volts
        public static let upperBound = 3.6 // volts
    }

    public struct CloudConnection {
        public static let minUnseenDuration: Int = 2     // sec
        public static let defaultUnseenDuration: Int = 900     // sec
    }
}
