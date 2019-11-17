import UIKit
import Localize_Swift

protocol CardViewDelegate: class {
    func card(view: CardView, didTriggerSettings sender: Any)
    func card(view: CardView, didTriggerCharts sender: Any)
}

class CardView: UIView {
    
    weak var delegate: CardViewDelegate?
    
    @IBOutlet weak var humidityWarningImageView: UIImageView!
    @IBOutlet weak var chartsButtonContainerView: UIView!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var rssiCityLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var rssiCityImageView: UIImageView!
    
    var updatedAt: Date?
    
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            self?.updatedLabel.text = self?.updatedAt?.ruuviAgo ?? "N/A".localized()
        })
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: { [weak self] in
            self?.humidityWarningImageView.alpha = 0.0
        })
    }
    
    @IBAction func chartsButtonTouchUpInside(_ sender: Any) {
        delegate?.card(view: self, didTriggerCharts: sender)
    }
    
    @IBAction func settingsButtonTouchUpInside(_ sender: Any) {
        delegate?.card(view: self, didTriggerSettings: sender)
    }
    
}
