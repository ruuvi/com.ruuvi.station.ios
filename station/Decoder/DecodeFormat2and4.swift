import Foundation

class DecodeFormat2and4: RuuviTagDecoder {
    func decode(data: Data) -> RuuviTag {
        let ruuviTag = RuuviTag()
        ruuviTag.dataFormat = Int(data[0])
        ruuviTag.humidity = ((Double) (data[1] & 0xFF)) / 2.0
        let uTemp = Double((UInt16(data[2] & 127) << 8) | UInt16(data[3]))
        let tempSign = UInt16(data[2] >> 7) & UInt16(1)
        ruuviTag.temperature = tempSign == 0 ? uTemp / 256.0 : -1.00 * uTemp / 256.0
        ruuviTag.pressure = Double(((UInt16(data[4]) << 8) + UInt16(data[5]))) + 50000
        ruuviTag.pressure /= 100.00;
        ruuviTag.updatedAt = NSDate()
        return ruuviTag
    }
}
