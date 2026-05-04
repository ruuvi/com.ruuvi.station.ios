#if DEBUG || ALPHA
import RuuviNotification
import UIKit

final class AlertDebugLogViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Alert Debug Log"
        view.backgroundColor = .systemBackground
        setupNavigationItems()
        setupTextView()
        loadLogs()
    }

    private func setupNavigationItems() {
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                barButtonSystemItem: .action,
                target: self,
                action: #selector(shareTapped)
            ),
            UIBarButtonItem(
                barButtonSystemItem: .refresh,
                target: self,
                action: #selector(loadLogs)
            ),
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearTapped)
        )
    }

    private func setupTextView() {
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func loadLogs() {
        let text = RuuviAlertDebugLog.text()
        textView.text = text.isEmpty ? "No alert debug entries yet." : text
        scrollToBottom()
    }

    @objc private func shareTapped() {
        let activityItems: [Any]
        if let url = try? RuuviAlertDebugLog.exportFileURL() {
            activityItems = [url]
        } else {
            activityItems = [RuuviAlertDebugLog.text()]
        }

        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.popoverPresentationController?.barButtonItem =
            navigationItem.rightBarButtonItems?.first
        present(controller, animated: true)
    }

    @objc private func clearTapped() {
        RuuviAlertDebugLog.clear()
        textView.text = "Cleared. New entries will appear after the next alert event."
    }

    private func scrollToBottom() {
        guard !textView.text.isEmpty else { return }
        let bottom = NSRange(location: textView.text.count - 1, length: 0)
        textView.scrollRangeToVisible(bottom)
    }
}
#endif
