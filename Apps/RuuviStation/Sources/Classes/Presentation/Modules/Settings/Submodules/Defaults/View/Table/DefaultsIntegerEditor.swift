import RuuviLocalization
import UIKit

enum DefaultsIntegerEditor {
    static func present(
        from presenter: UIViewController,
        title: String?,
        value: Int,
        configuration: DefaultsIntegerEditorConfiguration,
        onSave: @escaping (Int) -> Void
    ) {
        let alert = UIAlertController(title: title, message: configuration.message, preferredStyle: .alert)
        let save = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak alert] _ in
            guard let value = configuration.validatedValue(from: alert?.textFields?.first?.text) else { return }
            onSave(value)
        }
        save.isEnabled = configuration.range.contains(value)
        alert.addTextField { [save] textField in
            textField.keyboardType = .numberPad
            textField.clearButtonMode = .whileEditing
            textField.text = String(value)
            textField.addAction(UIAction { [weak save] action in
                let text = (action.sender as? UITextField)?.text
                save?.isEnabled = configuration.validatedValue(from: text) != nil
            }, for: .editingChanged)
        }
        for preset in configuration.presets where configuration.range.contains(preset.value) {
            alert.addAction(UIAlertAction(title: preset.title, style: .default) { _ in onSave(preset.value) })
        }
        alert.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel))
        alert.addAction(save)
        presenter.present(alert, animated: true) { alert.textFields?.first?.selectAll(nil) }
    }
}
