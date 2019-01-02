import Foundation

class DecodeFormat3: RuuviTagDecoder {
    func decode(data: Data) -> RuuviTag {
        let ruuviTag = RuuviTag()
        
        ruuviTag.humidity = Double(data[3]) * 0.5
        
        let temperatureSign = (data[4] >> 7) & 1
        let temperatureBase = data[4] & 0x7F
        let temperatureFraction = Double(data[5]) / 100.0
        var temperature = Double(temperatureBase) + temperatureFraction
        if (temperatureSign == 1) {
            temperature *= -1;
        }
        ruuviTag.temperature = temperature
        
        let pressureHi = data[6] & 0xFF
        let pressureLo = data[7] & 0xFF
        ruuviTag.pressure = Double(pressureHi) * 256.0 + 50000.0 + Double(pressureLo)
        ruuviTag.pressure /= 100.0;
        
        ruuviTag.accelerationX = Double(UInt16(data[8]) << 8 | UInt16(data[9] & 0xFF)) / 1000.0;
        ruuviTag.accelerationY = Double(UInt16(data[10]) << 8 | UInt16(data[11] & 0xFF)) / 1000.0;
        ruuviTag.accelerationZ = Double(UInt16(data[12]) << 8 | UInt16(data[13] & 0xFF)) / 1000.0;
        
        let battHi = data[14] & 0xFF;
        let battLo = data[15] & 0xFF;
        ruuviTag.voltage = (Double(battHi) * 256.0 + Double(battLo)) / 1000.0;
        
        ruuviTag.updatedAt = NSDate()
        return ruuviTag
    }
}
