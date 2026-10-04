import RuuviLocalization
import RuuviOntology
import UIKit

final class RuuviHistoryDatePicker: UIViewController {
    private let startPicker = UIDatePicker()
    private let endPicker = UIDatePicker()
    private let selection: RuuviHistorySelection
    private let onSelect: (Date, Date) -> Void

    init(selection: RuuviHistorySelection, onSelect: @escaping (Date, Date) -> Void) {
        self.selection = selection
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString(
            "history.custom",
            tableName: "History",
            value: "Custom dates…",
            comment: "History dates"
        )
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(done)
        )
        let range = selection.resolve()
        for picker in [startPicker, endPicker] {
            picker.datePickerMode = .date
            picker.preferredDatePickerStyle = .inline
            picker.minimumDate = RuuviHistoryRange.retained().start
            picker.maximumDate = Date()
            picker.addTarget(self, action: #selector(datesChanged), for: .valueChanged)
        }
        startPicker.date = range.start
        endPicker.date = min(Date(), range.end.addingTimeInterval(-1))
        let from = UILabel()
        from.text = NSLocalizedString(
            "history.from",
            tableName: "History",
            value: "From",
            comment: "First included day"
        )
        let through = UILabel()
        through.text = NSLocalizedString(
            "history.through",
            tableName: "History",
            value: "Through",
            comment: "Last included day"
        )
        let stack = UIStackView(arrangedSubviews: [from, startPicker, through, endPicker])
        stack.axis = .vertical
        stack.spacing = 12
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        datesChanged()
    }

    @objc private func datesChanged() {
        navigationItem.rightBarButtonItem?.isEnabled = Calendar.current.startOfDay(for: startPicker.date) <= Calendar
            .current.startOfDay(for: endPicker.date)
    }

    @objc private func cancel() { dismiss(animated: true) }
    @objc private func done() {
        onSelect(startPicker.date, endPicker.date)
        dismiss(animated: true)
    }
}
