import SwiftUI

@available(iOS 16.0, *)
struct SimpleWidgetViewInline: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry

    var body: some View {
        HStack {
            Text("\(entry.tag.displayString)  \(viewModel.getInlineWidgetValue(from: entry))")
        }.widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
