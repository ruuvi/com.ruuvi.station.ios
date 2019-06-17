import UIKit
import DateToolsSwift

class DashboardRuuviTagView: UIView {
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    
    var updatedAt = Date()
    
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            self?.updatedLabel.text = self?.updatedAt.timeAgoSinceNow
        })
    }
}
