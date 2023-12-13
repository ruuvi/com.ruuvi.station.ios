import AVFoundation
import Foundation
import RuuviLocalization
import RuuviOntology
import UIKit

// swiftlint:disable:next type_name
class PushAlertSoundSelectionTableViewController: UITableViewController {
    var output: PushAlertSoundSelectionViewOutput!
    var viewModel: PushAlertSoundSelectionViewModel? {
        didSet {
            updateUI()
        }
    }

    private var audioPlayer: AVAudioPlayer?

    init(title: String) {
        super.init(style: .grouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        audioPlayer?.invalidate()
        audioPlayer = nil
    }

    private let reuseIdentifier: String = "reuseIdentifier"
}

// MARK: - LIFECYCLE

extension PushAlertSoundSelectionTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output.viewDidLoad()
    }
}

extension PushAlertSoundSelectionTableViewController: PushAlertSoundSelectionViewInput {
    func localize() {
        // no op.
    }

    func playSelectedSound(from sound: RuuviAlertSound) {
        switch sound {
        case .systemDefault:
            break
        default:
            playSound(from: sound)
        }
    }
}

private extension PushAlertSoundSelectionTableViewController {
    func setUpUI() {
        view.backgroundColor = RuuviColor.primary.color
        setUpTableView()
    }

    func setUpTableView() {
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(
            PushAlertSelectionTableViewCell.self,
            forCellReuseIdentifier: reuseIdentifier
        )
    }

    func updateUI() {
        if isViewLoaded {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension PushAlertSoundSelectionTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.items.count ?? 0
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? PushAlertSelectionTableViewCell
        else {
            fatalError()
        }
        if let viewModel {
            let item = viewModel.items[indexPath.row]
            cell.configure(
                title: item.title(""),
                selection: viewModel.selection.title("")
            )
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PushAlertSoundSelectionTableViewController {
    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let viewModel {
            output.viewDidSelectItem(item: viewModel.items[indexPath.row])
        }
    }
}

// MARK: - Audio Player

extension PushAlertSoundSelectionTableViewController {
    func playSound(from sound: RuuviAlertSound) {
        audioPlayer?.invalidate()
        audioPlayer = nil

        guard let audioURL = Bundle.main.url(
            forResource: sound.fileName,
            withExtension: "caf"
        )
        else {
            return
        }

        do {
            audioPlayer = try? AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        }
    }
}
