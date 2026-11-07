import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class NativeFeedbackPresentationTests: XCTestCase {
    func testAlertPresenterShowsTheOriginalMessageAndActionsOnTheActiveScreen() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        defer { host.close() }
        let retry = UIAlertAction(title: "Retry", style: .default)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        AlertPresenterImpl().showAlert(
            .init(
                title: "Could not load history", message: "Try again when connected",
                style: .alert, actions: [retry, cancel]))
        await waitForAppState("native error alert attached") { root.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Could not load history")
        XCTAssertEqual(alert.message, "Try again when connected")
        XCTAssertEqual(alert.preferredStyle, .alert)
        XCTAssertEqual(alert.actions.count, 2)
        XCTAssertTrue(alert.actions[0] === retry)
        XCTAssertTrue(alert.actions[1] === cancel)
    }

    func testSoundFactoryConnectsTheRealScreenAndSelectionUpdatesOnlyTheSoundPreference() async throws {
        let view = PushAlertSoundSelectionModuleFactoryImpl().create(with: "Alert sound")
        let presenter = try XCTUnwrap(view.output as? PushAlertSoundSelectionPresenter)
        let settings = AppTestSettings()
        settings.alertSound = .ruuviSpeak
        settings.temperatureUnit = .fahrenheit
        presenter.settings = settings
        presenter.configure(
            viewModel: .init(
                title: "Alert sound", items: [RuuviAlertSound.systemDefault, RuuviAlertSound.ruuviSpeak],
                selection: RuuviAlertSound.ruuviSpeak))
        let host = try AppViewHost(view)
        defer { host.close() }
        XCTAssertTrue(presenter.view === view)
        let first = IndexPath(row: 0, section: 0)
        view.tableView(view.tableView, didSelectRowAt: first)
        await flushAppBindings()
        XCTAssertEqual(settings.alertSound, .systemDefault)
        XCTAssertEqual(settings.temperatureUnit, .fahrenheit)
        XCTAssertEqual(view.viewModel?.selection as? RuuviAlertSound, .systemDefault)
        XCTAssertEqual(view.tableView.cellForRow(at: first)?.accessoryType, .checkmark)
        let audio = SoundPreviewSpy()
        presenter.view = audio
        presenter.viewDidSelectItem(item: RuuviAlertSound.ruuviSpeak)
        XCTAssertEqual(audio.sounds, [.ruuviSpeak])
        XCTAssertEqual(settings.alertSound, .ruuviSpeak)
        XCTAssertEqual(audio.viewModel?.selection as? RuuviAlertSound, .ruuviSpeak)
        presenter.viewDidSelectItem(item: TemperatureUnit.kelvin)
        XCTAssertEqual(audio.sounds.count, 1)
        XCTAssertEqual(settings.temperatureUnit, .fahrenheit)
    }
}
private final class SoundPreviewSpy: PushAlertSoundSelectionViewInput {
    var viewModel: PushAlertSoundSelectionViewModel?
    var sounds = [RuuviAlertSound]()
    func localize() {}
    func playSelectedSound(from sound: RuuviAlertSound) { sounds.append(sound) }
}
