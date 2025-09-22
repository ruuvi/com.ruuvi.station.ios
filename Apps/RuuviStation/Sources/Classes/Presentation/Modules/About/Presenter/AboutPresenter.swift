import Foundation
import RuuviContext
import RuuviLocalization
import RuuviStorage
import UIKit

final class AboutPresenter: AboutModuleInput {
    weak var view: AboutViewInput!
    var router: AboutRouterInput!
    var ruuviStorage: RuuviStorage!
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
            value: UIFont.ruuviFootnote(),
            range: range
        )

        // Change changelog color
        let changelogFont = UIFont.ruuviFootnote()
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
        Task { [weak self] in
            guard let self else { return }
            do {
                let count = try await ruuviStorage.getStoredTagsCount()
                let tagsCount = RuuviLocalization.About.TagsCount.text(count)
                await MainActor.run { [weak self] in
                    self?.viewModel.addedTags.value = tagsCount
                }
            } catch { /* non-critical */ }
        }
    }

    private func obtainMeasurementsCount() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let count = try await ruuviStorage.getStoredMeasurementsCount()
                let measurementsCount = RuuviLocalization.About.MeasurementsCount.text(count)
                await MainActor.run { [weak self] in
                    self?.viewModel.storedMeasurements.value = measurementsCount
                }
            } catch { /* non-critical */ }
        }
    }

    private func obtainDatabaseSize() {
        let sqliteSize = getSQLiteFileSize()
        let dbSize = ByteCountFormatter().string(fromByteCount: sqliteSize)
        let dbSizeString = RuuviLocalization.About.DatabaseSize.text(dbSize)
        viewModel.databaseSize.value = dbSizeString
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
