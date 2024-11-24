/// Contains all the constants for the TagSettingsAlert.
struct TagSettingsAlertConstants {
    struct Temperature {
        static let lowerBound = -40.0 // Celsius
        static let upperBound = 85.0  // Celsius

        static let customLowerBound = -55.0 // Celsius
        static let customUpperBound = 150.0  // Celsius
    }

    struct RelativeHumidity {
        static let lowerBound = 0.0   // Percentage (%)
        static let upperBound = 100.0 // Percentage (%)
    }

    struct Pressure {
        static let lowerBound = 500.0  // hPa
        static let upperBound = 1155.0 // hPa
    }

    struct Signal {
        static let lowerBound = -105.0 // dBm
        static let upperBound = 0.0    // dBm
    }

    struct CarbonDioxide {
        static let lowerBound = 350.0  // ppm
        static let upperBound = 2500.0 // ppm
    }

    struct ParticulateMatter {
        static let lowerBound = 0.0   // µg/m³
        static let upperBound = 250.0 // µg/m³
    }

    struct VOC {
        static let lowerBound = 0.0   // VOC Index
        static let upperBound = 500.0 // VOC Index
    }

    struct NOX {
        static let lowerBound = 0.0   // NOx Index
        static let upperBound = 500.0 // NOx Index
    }

    struct Sound {
        static let lowerBound = 0.0    // dB
        static let upperBound = 127.0  // dB
    }

    struct Luminosity {
        static let lowerBound = 0.0     // lx
        static let upperBound = 10000.0 // lx
    }

    struct CloudConnection {
        static let minUnseenDuration: Int = 2     // sec
        static let defaultUnseenDuration: Int = 900     // sec
    }
}
