import Foundation

/// Decodes Ruuvi Data Format 5 (RAWv2) from a BLE advertisement hex string.
/// Spec: https://docs.ruuvi.com/communication/bluetooth-advertisements/data-format-5-rawv2
enum RuuviDF5Parser {

    struct Measurement {
        // Primary
        let temperature: Double?   // °C
        let humidity: Double?      // %RH
        let pressure: Double?      // hPa
        // Power
        let voltage: Double?       // V
        let txPower: Int?          // dBm
        // Motion
        let accelerationX: Double? // g
        let accelerationY: Double? // g
        let accelerationZ: Double? // g
        let movementCounter: Int?
        let measurementSequenceNumber: Int?
    }

    static func parse(hexString: String) -> Measurement? {
        let bytes = rawBytes(from: hexString)
        guard bytes.count > 10,
              let offset = findDF5Offset(in: bytes),
              bytes.count >= offset + 20
        else { return nil }

        // Temperature — signed int16, units 0.005 °C
        let tempRaw = Int16(bitPattern: UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1]))
        // Humidity — uint16, units 0.0025 %
        let humRaw  = UInt16(bytes[offset + 2]) << 8 | UInt16(bytes[offset + 3])
        // Pressure — uint16, offset 50 000 Pa, units 1 Pa → /100 for hPa
        let presRaw = UInt16(bytes[offset + 4]) << 8 | UInt16(bytes[offset + 5])
        // Acceleration — signed int16, units 1 mg → /1000 for g
        let accXRaw = Int16(bitPattern: UInt16(bytes[offset + 6])  << 8 | UInt16(bytes[offset + 7]))
        let accYRaw = Int16(bitPattern: UInt16(bytes[offset + 8])  << 8 | UInt16(bytes[offset + 9]))
        let accZRaw = Int16(bitPattern: UInt16(bytes[offset + 10]) << 8 | UInt16(bytes[offset + 11]))
        // Power source (bits 15:5) + TX power (bits 4:0)
        let powerRaw = UInt16(bytes[offset + 12]) << 8 | UInt16(bytes[offset + 13])
        // Movement counter — uint8
        let movRaw = bytes[offset + 14]
        // Measurement sequence number — uint16
        let msnRaw = UInt16(bytes[offset + 15]) << 8 | UInt16(bytes[offset + 16])

        let temperature: Double? = tempRaw != Int16(bitPattern: 0x8000) ? Double(tempRaw) * 0.005 : nil
        let humidity: Double?    = humRaw  != 0xFFFF ? Double(humRaw)  * 0.0025 : nil
        let pressure: Double?    = presRaw != 0xFFFF ? (Double(presRaw) + 50_000.0) / 100.0 : nil

        let accX: Double? = accXRaw != Int16(bitPattern: 0x8000) ? Double(accXRaw) / 1000.0 : nil
        let accY: Double? = accYRaw != Int16(bitPattern: 0x8000) ? Double(accYRaw) / 1000.0 : nil
        let accZ: Double? = accZRaw != Int16(bitPattern: 0x8000) ? Double(accZRaw) / 1000.0 : nil

        let voltageRaw = powerRaw >> 5
        let voltage: Double? = voltageRaw != 0x7FF ? Double(voltageRaw + 1600) / 1000.0 : nil

        let txPowerRaw = Int(powerRaw & 0x1F)
        let txPower: Int? = txPowerRaw != 0x1F ? txPowerRaw * 2 - 40 : nil

        let movementCounter: Int? = movRaw != 0xFF ? Int(movRaw) : nil
        let msn: Int? = msnRaw != 0xFFFF ? Int(msnRaw) : nil

        return Measurement(
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            voltage: voltage,
            txPower: txPower,
            accelerationX: accX,
            accelerationY: accY,
            accelerationZ: accZ,
            movementCounter: movementCounter,
            measurementSequenceNumber: msn
        )
    }

    // MARK: - Private

    private static func findDF5Offset(in bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4 else { return nil }
        for i in 0 ..< bytes.count - 4 {
            if bytes[i]     == 0xFF,
               bytes[i + 1] == 0x99,
               bytes[i + 2] == 0x04,
               bytes[i + 3] == 0x05 {
                return i + 4
            }
        }
        return nil
    }

    private static func rawBytes(from hex: String) -> [UInt8] {
        let clean = hex.replacingOccurrences(of: " ", with: "")
        var result = [UInt8]()
        result.reserveCapacity(clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex,
              let next = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex) {
            if let byte = UInt8(clean[index ..< next], radix: 16) {
                result.append(byte)
            }
            index = next
        }
        return result
    }
}
