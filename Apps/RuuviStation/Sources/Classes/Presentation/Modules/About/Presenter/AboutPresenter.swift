import Foundation
import RuuviContext
import RuuviLocalization
import RuuviStorage
import UIKit

final class AboutPresenter: AboutModuleInput {
    weak var view: AboutViewInput!
    var router: AboutRouterInput!
    var ruuviStorage: RuuviStorage!
    var realmContext: RealmContext!
    var sqliteContext: SQLiteContext!

    private var viewModel: AboutViewModel {
        view.viewModel
    }
}

// MARK: - AboutViewOutput

extension AboutPresenter: AboutViewOutput {
    func viewDidLoad() {
        syncViewModel()
    }

    func viewDidTriggerClose() {
        router.dismiss()
    }

    func viewDidTapChangelog() {
        router.openChangelogPage()
    }
}

// MARK: - Private

extension AboutPresenter {
    private func syncViewModel() {
        viewModel.version.value = appVersion
        obtainTagsCount()
        obtainMeasurementsCount()
        obtainDatabaseSize()
    }

    private var appVersion: NSMutableAttributedString? {
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        else {
            return nil
        }
        let changelogString = RuuviLocalization.changelog
        let versionText = RuuviLocalization.About.Version.text + " " + appVersion + "(" + buildVersion + ")"

        let text = versionText + " " + changelogString

        let attrString = NSMutableAttributedString(string: text)
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.Muli(.regular, size: 14),
            range: range
        )

        // Change changelog color
        let changelogFont = UIFont.Muli(.regular, size: 13)
        let changelogRange = NSString(string: attrString.string).range(of: changelogString)
        attrString.addAttribute(
            NSAttributedString.Key.font,
            value: changelogFont,
            range: changelogRange
        )
        attrString.addAttribute(
            .foregroundColor,
            value: RuuviColor.tintColor.color,
            range: changelogRange
        )

        // Change rest of the text color
        let regularRange = NSString(string: attrString.string)
            .range(of: versionText)
        attrString.addAttribute(
            .foregroundColor,
            value: RuuviColor.dashboardIndicator.color,
            range: regularRange
        )

        return attrString
    }

    private func obtainTagsCount() {
        ruuviStorage.getStoredTagsCount().on(success: { [weak self] count in
            let tagsCount = RuuviLocalization.About.TagsCount.text(count)
            self?.viewModel.addedTags.value = tagsCount
        })
    }

    private func obtainMeasurementsCount() {
        ruuviStorage.getStoredMeasurementsCount().on(success: { [weak self] count in
            let measurementsCount = RuuviLocalization.About.MeasurementsCount.text(count)
            self?.viewModel.storedMeasurements.value = measurementsCount
        })
    }

    private func obtainDatabaseSize() {
        let realmSize = getRealmFileSize()
        let sqliteSize = getSQLiteFileSize()
        let dbSize = ByteCountFormatter().string(fromByteCount: realmSize + sqliteSize)
        let dbSizeString = RuuviLocalization.About.DatabaseSize.text(dbSize)
        viewModel.databaseSize.value = dbSizeString
    }

    func getRealmFileSize() -> Int64 {
        guard let realmPath = realmContext.main.configuration.fileURL?.relativePath
        else {
            return 0
        }
        return fileSize(at: realmPath)
    }

    func getSQLiteFileSize() -> Int64 {
        fileSize(at: sqliteContext.database.dbPath)
    }

    func fileSize(at path: String) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[FileAttributeKey.size] as? Int64
        else {
            return 0
        }
        return fileSize
    }
}
