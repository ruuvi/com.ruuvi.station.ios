import SwiftUI

@available(iOS 16.0, *)
struct SimpleWidgetViewInline: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry

    var body: some View {
        HStack {
            // swiftlint:disable:next line_length
            Text("\(entry.tag.displayString) \(viewModel.symbol(from: entry)) \(viewModel.getInlineWidgetValue(from: entry))")
                .environment(\.locale, viewModel.locale())
        }.widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
