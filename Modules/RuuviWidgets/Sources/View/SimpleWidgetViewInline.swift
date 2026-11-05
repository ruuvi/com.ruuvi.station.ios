import SwiftUI

@available(iOS 16.0, *)
struct SimpleWidgetViewInline: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetEntry

    var body: some View {
        HStack {
            Text("\(entry.tag.displayString)  \(viewModel.getInlineWidgetValue(from: entry))")
        }
        .widgetURL(
            viewModel.widgetDeepLinkURL(
                sensorId: entry.tag.identifier,
                record: entry.record
            )
        )
    }
}
