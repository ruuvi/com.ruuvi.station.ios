import UIKit
import Foundation
import AVFoundation
import RuuviOntology

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

    required init?(coder aDecoder: NSCoder) {
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
        setupLocalization()
        setUpUI()
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

extension PushAlertSoundSelectionTableViewController {
    fileprivate func setUpUI() {
        view.backgroundColor = RuuviColor.ruuviPrimary
        setUpTableView()
    }

    fileprivate func setUpTableView() {
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(PushAlertSelectionTableViewCell.self,
                           forCellReuseIdentifier: reuseIdentifier)
    }

    fileprivate func updateUI() {
        if isViewLoaded {
            DispatchQueue.main.async(execute: { [weak self] in
                self?.tableView.reloadData()
            })
        }
    }
}

// MARK: - UITableViewDataSource
extension PushAlertSoundSelectionTableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.items.count ?? 0
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? PushAlertSelectionTableViewCell else {
            fatalError()
        }
        if let viewModel = viewModel {
            let item = viewModel.items[indexPath.row]
            cell.configure(
                title: item.title,
                selection: viewModel.selection.title
            )
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PushAlertSoundSelectionTableViewController {
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let viewModel = viewModel {
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
        ) else {
            return
        }

        do {
            audioPlayer = try? AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        }
    }

}
