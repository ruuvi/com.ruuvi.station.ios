import CoreBluetooth

class RuuviTagScanner: NSObject, CBCentralManagerDelegate {
    var peripherals:[CBPeripheral] = []
    var manager: CBCentralManager? = nil
    var caller: RuuviTagListener?
    var ready = false
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            ready = true
            start()
        } else {
            caller?.bluetoothDisabled()
        }
    }
    
    init(caller: RuuviTagListener) {
        super.init()
        self.caller = caller
        manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func start() {
        print("scan start")
        if ready {
            manager?.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func stop() {
        manager?.stopScan()
        print("scan stopped")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData:
        [String : Any], rssi RSSI: NSNumber) {
        if let manufacturerData = advertisementData[CBAdvertisementDataServiceDataKey] as? [NSObject:AnyObject] {
            if let manufacturerData = manufacturerData.first?.value as? Data{
                if manufacturerData.count != 20 {
                    return
                }
                if let url = String(data: manufacturerData[3 ... manufacturerData.count - 1], encoding: .utf8) {
                    if url.starts(with: "ruu.vi/#") {
                        var urlData = url.replacingOccurrences(of: "ruu.vi/#", with: "")
                        urlData = urlData.padding(toLength: ((urlData.count+3)/4)*4,
                                          withPad: "AAA",
                                          startingAt: 0)
                        if let data = Data(base64Encoded: urlData) {
                            let tag = DecodeFormat2and4().decode(data: data)
                            tag.rssi = RSSI.intValue
                            tag.uuid = peripheral.identifier.uuidString
                            notifyListeners(tag: tag)
                        }
                    }
                }
            }
        }
        
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            if manufacturerData.count < 3 {
                return
            }
            let manufactureID = UInt16(manufacturerData[0]) + UInt16(manufacturerData[1]) << 8
            if manufactureID == 0x0499 {
                let dataFormat = manufacturerData[2]
                var tag: RuuviTag?
                switch (dataFormat) {
                case 3:
                    if manufacturerData.count < 15 {
                        return
                    }
                    tag = DecodeFormat3().decode(data: manufacturerData)
                    break
                case 5:
                    if manufacturerData.count < 26 {
                        return
                    }
                    tag = DecodeFormat5().decode(data: manufacturerData)
                    break
                default:
                    print("unsupported data format")
                    return;
                }
                if let tag = tag {
                    tag.dataFormat = Int(dataFormat)
                    tag.rssi = RSSI.intValue
                    tag.uuid = peripheral.identifier.uuidString
                    notifyListeners(tag: tag)
                }
            }
        }
    }
    
    func notifyListeners(tag: RuuviTag) {
        let dbTag = RuuviTag().get(uuid: tag.uuid)
        if dbTag != nil {
            tag.name = (dbTag?.name)!
            tag.defaultBackground = (dbTag?.defaultBackground)!
            tag.update()
        }
        caller?.found(tag: tag)
    }
    
    func centralManager( central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        //print(error!)
    }
}
