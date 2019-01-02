import Foundation

class DecodeFormat5: RuuviTagDecoder {
    func decode(data: Data) -> RuuviTag {
        let ruuviTag = RuuviTag()
        
        ruuviTag.humidity = Double(UInt16(data[5] & 0xFF) << 8 | UInt16(data[6] & 0xFF)) / 400.0
        ruuviTag.temperature = Double(UInt16(data[3]) << 8 | UInt16(data[4] & 0xFF))
        if ruuviTag.temperature > 32767 {
            ruuviTag.temperature -= 65534
        }
        ruuviTag.temperature /= 200.0;
        ruuviTag.pressure = Double(UInt16(data[7] & 0xFF) << 8 | UInt16(data[8] & 0xFF)) + 50000
        ruuviTag.pressure /= 100.0;
        
        ruuviTag.accelerationX = Double(UInt16(data[9]) << 8 | UInt16(data[10] & 0xFF)) / 1000.0
        ruuviTag.accelerationY = Double(UInt16(data[11]) << 8 | UInt16(data[12] & 0xFF)) / 1000.0
        ruuviTag.accelerationZ = Double(UInt16(data[13]) << 8 | UInt16(data[14] & 0xFF)) / 1000.0
        
        let powerInfo = UInt32(UInt16(data[15] & 0xFF) << 8 | UInt16(data[16] & 0xFF))
        if ((powerInfo >>> UInt32(5)) != 0b11111111111) {
            ruuviTag.voltage = Double(powerInfo >>> UInt32(5)) / 1000.0 + 1.6
            ruuviTag.voltage = (ruuviTag.voltage*1000).rounded()/1000
        }
        if ((powerInfo & 0b11111) != 0b11111) {
            ruuviTag.txPower = Int((powerInfo & 0b11111) * 2 - 40)
        }
        ruuviTag.movementCounter = Int(data[18] & 0xFF)
        ruuviTag.measurementSequenceNumber = Int(UInt16(data[20] & 0xFF) << 8 | UInt16(data[19] & 0xFF))
        
        let asStr = data.hexEncodedString()
        let start = asStr.index(asStr.endIndex, offsetBy: -12)
        ruuviTag.mac = fixId(mac: asStr.substring(from: start))
        ruuviTag.updatedAt = NSDate()
        return ruuviTag
    }
    
    func fixId(mac: String) -> String {
        let out = NSMutableString(string: mac)
        var i = mac.count - 2
        while (i > 0) {
            out.insert(":", at: i)
            i -= 2
        }
        return out.uppercased as String
    }
}
