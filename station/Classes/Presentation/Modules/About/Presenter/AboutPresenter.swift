import Foundation
import RuuviContext

class AboutPresenter: AboutModuleInput {
    weak var view: AboutViewInput!
    var router: AboutRouterInput!
    var ruuviTagTrunk: RuuviTagTrunk!
    var realmContext: RealmContext!
    var sqliteContext: SQLiteContext!

    private var viewModel: AboutViewModel {
        return view.viewModel
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
}

// MARK: - Private
extension AboutPresenter {

    private func syncViewModel() {
        viewModel.version.value = appVersion
        obtainTagsCount()
        obtainMeasurementsCount()
        obtainDatabaseSize()
    }

    private var appVersion: String? {
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String  else {
            return nil
        }
        return "About.Version.text".localized() + " " + appVersion + "(" + buildVersion + ")"
    }

    private func obtainTagsCount() {
        ruuviTagTrunk.getStoredTagsCount().on(success: { [weak self] count in
            let tagsCount = String(format: "About.TagsCount.text".localized(), count)
            self?.viewModel.addedTags.value = tagsCount
        })
    }

    private func obtainMeasurementsCount() {
        ruuviTagTrunk.getStoredMeasurementsCount().on(success: { [weak self] count in
            let measurementsCount = String(format: "About.MeasurementsCount.text".localized(), count)
            self?.viewModel.storedMeasurements.value = measurementsCount
        })
    }

    private func obtainDatabaseSize() {
        let realmSize = getRealmFileSize()
        let sqliteSize = getSQLiteFileSize()
        let dbSize = ByteCountFormatter().string(fromByteCount: realmSize + sqliteSize)
        let dbSizeString = String(format: "About.DatabaseSize.text".localized(), dbSize)
        viewModel.databaseSize.value = dbSizeString
    }

    func getRealmFileSize() -> Int64 {
        guard let realmPath = realmContext.main.configuration.fileURL?.relativePath else {
            return 0
        }
        return fileSize(at: realmPath)
    }

    func getSQLiteFileSize() -> Int64 {
        return fileSize(at: sqliteContext.database.dbPath)
    }

    func fileSize(at path: String) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let fileSize = attributes[FileAttributeKey.size] as? Int64 else {
            return 0
        }
        return fileSize
    }
}
