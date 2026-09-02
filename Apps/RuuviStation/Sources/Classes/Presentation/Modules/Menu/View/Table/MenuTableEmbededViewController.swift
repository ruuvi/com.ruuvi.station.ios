import RuuviLocalization
import RuuviLocal
import UIKit

class MenuTableEmbededViewController: UITableViewController, MenuViewInput {
    var output: MenuViewOutput!

    @IBOutlet var feedbackCell: UITableViewCell!
    @IBOutlet var addRuuviTagCell: UITableViewCell!
    @IBOutlet var aboutCell: UITableViewCell!
    @IBOutlet var whatToMeasureCell: UITableViewCell!
    @IBOutlet var getMoreSensorsCell: UITableViewCell!
    @IBOutlet var settingsCell: UITableViewCell!
    @IBOutlet var accountCell: UITableViewCell!
    @IBOutlet var feedbackLabel: UILabel!
    @IBOutlet var addANewSensorLabel: UILabel!
    @IBOutlet var appSettingsLabel: UILabel!
    @IBOutlet var aboutHelpLabel: UILabel!
    @IBOutlet var whatToMeasureLabel: UILabel!
    @IBOutlet var getMoreSensorsLabel: UILabel!
    @IBOutlet var accountAuthLabel: UILabel!

    private var marketingPreferenceObserver: NSObjectProtocol?
    private var newsletterView: MenuNewsletterView?

    deinit {
        if let marketingPreferenceObserver {
            NotificationCenter.default.removeObserver(marketingPreferenceObserver)
        }
    }
}

// MARK: - MenuViewInput

extension MenuTableEmbededViewController {
    func localize() {
        addANewSensorLabel.text = RuuviLocalization.Menu.Label.AddAnNewSensor.text
        appSettingsLabel.text = RuuviLocalization.Menu.Label.AppSettings.text
        aboutHelpLabel.text = RuuviLocalization.Menu.Label.AboutHelp.text
        whatToMeasureLabel.text = RuuviLocalization.Menu.Label.WhatToMeasure.text
        getMoreSensorsLabel.text = RuuviLocalization.Menu.Label.GetMoreSensors.text
        feedbackLabel.text = RuuviLocalization.Menu.Label.Feedback.text
    }

    func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
        addANewSensorLabel.textColor = RuuviColor.menuTextColor.color
        appSettingsLabel.textColor = RuuviColor.menuTextColor.color
        aboutHelpLabel.textColor = RuuviColor.menuTextColor.color
        whatToMeasureLabel.textColor = RuuviColor.menuTextColor.color
        getMoreSensorsLabel.textColor = RuuviColor.menuTextColor.color
        feedbackLabel.textColor = RuuviColor.menuTextColor.color
        accountAuthLabel.textColor = RuuviColor.menuTextColor.color

        [
            addANewSensorLabel,
            appSettingsLabel,
            aboutHelpLabel,
            whatToMeasureLabel,
            getMoreSensorsLabel,
            feedbackLabel,
            accountAuthLabel,
        ].forEach {
            $0?.font = UIFont.ruuviButtonMedium()
        }
    }
}

// MARK: - View lifecycle

extension MenuTableEmbededViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        styleViews()
        observeMarketingPreference()
        updateNewsletter()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
        updateNewsletter()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateNewsletterFooterHeight()
    }

    private func observeMarketingPreference() {
        marketingPreferenceObserver = NotificationCenter.default.addObserver(
            forName: .MarketingPreferenceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateNewsletter()
        }
    }

    private func updateNewsletter() {
        guard output.shouldShowNewsletter else {
            newsletterView = nil
            tableView.tableFooterView = UIView(frame: .zero)
            return
        }

        if newsletterView == nil {
            let newsletterView = MenuNewsletterView(frame: .zero)
            newsletterView.onSubscribe = { [weak self] in
                self?.output.viewDidSelectNewsletter()
            }
            self.newsletterView = newsletterView
            tableView.tableFooterView = newsletterView
        }
        updateNewsletterFooterHeight()
    }

    private func updateNewsletterFooterHeight() {
        guard
            let newsletterView,
            tableView.numberOfSections > 0
        else {
            return
        }

        let lastSection = tableView.numberOfSections - 1
        let rowsBottom = tableView.rect(forSection: lastSection).maxY
        let visibleBottom = tableView.bounds.height - tableView.adjustedContentInset.bottom
        let footerHeight = max(320, visibleBottom - rowsBottom)

        guard
            newsletterView.frame.width != tableView.bounds.width ||
            newsletterView.frame.height != footerHeight
        else {
            return
        }

        newsletterView.frame = CGRect(
            x: 0,
            y: 0,
            width: tableView.bounds.width,
            height: footerHeight
        )
        tableView.tableFooterView = newsletterView
    }
}

// MARK: - UITableViewDelegate

extension MenuTableEmbededViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        44
    }

    override func tableView(
        _: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt _: IndexPath
    ) {
        if cell == accountCell {
            accountAuthLabel.text = output.userIsAuthorized
                ? RuuviLocalization.Menu.Label.MyRuuviAccount.text
                : RuuviLocalization.SignIn.Title.text
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case addRuuviTagCell:
                output.viewDidSelectAddRuuviTag()
            case aboutCell:
                output.viewDidSelectAbout()
            case whatToMeasureCell:
                output.viewDidSelectWhatToMeasure()
            case getMoreSensorsCell:
                output.viewDidSelectGetMoreSensors()
            case settingsCell:
                output.viewDidSelectSettings()
            case feedbackCell:
                output.viewDidSelectFeedback()
            case accountCell:
                output.viewDidSelectAccountCell()
            default:
                break
            }
        }
    }
}
