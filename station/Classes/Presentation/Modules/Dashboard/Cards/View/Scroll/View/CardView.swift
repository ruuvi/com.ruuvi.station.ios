import UIKit
import Localize_Swift
import RuuviOntology
import RuuviLocal

protocol CardViewDelegate: AnyObject {
    func card(view: CardView, didTriggerSettings sender: Any, scrollToAlert: Bool)
    func card(view: CardView, didTriggerCharts sender: Any)
}

class CardView: UIView {

    weak var delegate: CardViewDelegate?

    @IBOutlet weak var chartsButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var alertImageView: UIImageView!
    @IBOutlet weak var alertView: UIView!
    @IBOutlet weak var humidityWarningImageView: UIImageView!
    @IBOutlet weak var chartsButtonContainerView: UIView!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var movementCityLabel: UILabel!
    @IBOutlet weak var movementCityTitleLbl: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var movementCityImageView: UIImageView!
    @IBOutlet weak var dataSourceImageView: UIImageView!
    @IBOutlet weak var humidityView: UIView!
    @IBOutlet weak var humidityViewHeight: NSLayoutConstraint!
    @IBOutlet weak var pressureView: UIView!
    @IBOutlet weak var pressureViewHeight: NSLayoutConstraint!
    @IBOutlet weak var movementCounterView: UIView!
    @IBOutlet weak var movementCounterViewHeight: NSLayoutConstraint!

    var updatedAt: Date?
    var isConnected: Bool?
    var networkTagMacId: MACIdentifier? {
        didSet {
            guard networkTagMacId != nil else {
                notificationToken?.invalidate()
                startTimer()
                return
            }
            startObservingNetworkSyncNotification()
        }
    }
    var syncStatus: NetworkSyncStatus = .none {
        didSet {
            updateSyncLabel(with: syncStatus)
        }
    }

    var hideHumidityView: Bool = false {
        didSet {
            updateHumidityView(with: hideHumidityView)
        }
    }

    var hidePressureView: Bool = false {
        didSet {
            updatePressureView(with: hidePressureView)
        }
    }

    var hideMovementCounterView: Bool = false {
        didSet {
            updateMovementCounterView(with: hideMovementCounterView)
        }
    }

    private var notificationToken: NSObjectProtocol?
    private var isSyncing: Bool = false

    private var timer: Timer?

    deinit {
        notificationToken?.invalidate()
        timer?.invalidate()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: { [weak self] in
            self?.humidityWarningImageView.alpha = 0.0
        })
    }

    @IBAction func alertBellButtonTouchUpInside(_ sender: Any) {
        delegate?.card(view: self, didTriggerSettings: sender, scrollToAlert: true)
    }

    @IBAction func chartsButtonTouchUpInside(_ sender: Any) {
        delegate?.card(view: self, didTriggerCharts: sender)
    }

    @IBAction func settingsButtonTouchUpInside(_ sender: Any) {
        delegate?.card(view: self, didTriggerSettings: sender, scrollToAlert: false)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (_) in
            guard self?.isSyncing == false else {
                return
            }
            if let isConnected = self?.isConnected,
               isConnected,
               let date = self?.updatedAt?.ruuviAgo() {
                self?.updatedLabel.text = date
            } else {
                self?.updatedLabel.text = self?.updatedAt?.ruuviAgo() ?? "Cards.UpdatedLabel.NoData.message".localized()
            }
        })
    }

    private func startObservingNetworkSyncNotification() {
        notificationToken = NotificationCenter
            .default
            .addObserver(forName: .NetworkSyncDidChangeStatus,
                         object: nil,
                         queue: .main,
                         using: { [weak self] notification in
            guard
                  let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus else {
                return
            }
            self?.updateSyncLabel(with: status)
        })
    }

    private func updateSyncLabel(with status: NetworkSyncStatus) {
        timer?.invalidate()
        switch status {
        case .none:
            isSyncing = false
            startTimer()
        case .syncing:
            isSyncing = true
            updatedLabel.text = "TagCharts.Status.Serving".localized()
        case .complete:
            updatedLabel.text = "Synchronized".localized()
        case .onError:
            updatedLabel.text = "ErrorPresenterAlert.Error".localized()
        }
    }

    private func updateHumidityView(with hideHumidity: Bool) {
        if hideHumidity {
            humidityView.isHidden = true
            humidityViewHeight.constant = 0
        } else {
            humidityView.isHidden = false
            humidityViewHeight.constant = 66
        }
    }

    private func updatePressureView(with hidePressure: Bool) {
        if hidePressure {
            pressureView.isHidden = true
            pressureViewHeight.constant = 0
        } else {
            pressureView.isHidden = false
            pressureViewHeight.constant = 66
        }
    }

    private func updateMovementCounterView(with hideMovementCounter: Bool) {
        if hideMovementCounter {
            movementCounterView.isHidden = true
            movementCounterViewHeight.constant = 0
        } else {
            movementCounterView.isHidden = false
            movementCounterViewHeight.constant = 66
        }
    }
}
