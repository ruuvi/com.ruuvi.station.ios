import UIKit

public class TagView: UIView {
    var ruuviTag: RuuviTag? = nil
    
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var macLbl: UILabel!
    @IBOutlet weak var temperatureLbl: UILabel!
    @IBOutlet weak var humidityLbl: UILabel!
    @IBOutlet weak var pressureLbl: UILabel!
    @IBOutlet weak var rssiLbl: UILabel!
    @IBOutlet weak var updateLbl: UILabel!
    
    override public func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
    }
    
    func draw() {
        if ruuviTag != nil {
            if ruuviTag?.name != "" {
                macLbl.text = ruuviTag?.name.uppercased()
            } else if ruuviTag?.mac != "" {
                macLbl.text = ruuviTag?.mac.uppercased()
            } else {
                macLbl.text = ruuviTag?.uuid.uppercased()
            }
            let temperatureText = NSMutableAttributedString.init(string: String(format: "%.2f", ruuviTag!.temperature) + "")
            //temperatureText.setAttributes([kCTFontAttributeName as NSAttributedStringKey: UIFont.systemFont(ofSize: 32)],
            //                              range: NSMakeRange(temperatureText.length - 2, 2))
            temperatureLbl.attributedText = temperatureText
            //temperatureLbl.sizeToFit()
            humidityLbl.text = String(format: "%.2f", ruuviTag!.humidity) + " %"
            pressureLbl.text = String(ruuviTag!.pressure) + " hPa"
            rssiLbl.text = String(ruuviTag!.rssi) + " dBm"
            updateLbl.text = Utils().timeSince(date: ruuviTag!.updatedAt! as Date)

            //if backgroundImage.alpha == 0 {
                backgroundImage.image = UIImage(named: "bg" + String(ruuviTag!.defaultBackground) + ".png")
                //backgroundImage.alpha = 1
            //}
        }
    }

}
