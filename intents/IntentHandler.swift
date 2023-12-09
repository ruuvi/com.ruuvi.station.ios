import Intents

class IntentHandler: INExtension, RuuviTagSelectionIntentHandling {
    private let viewModel = WidgetViewModel()
    func provideRuuviWidgetTagOptionsCollection(for _: RuuviTagSelectionIntent,
                                                with completion: @escaping (INObjectCollection<RuuviWidgetTag>?,
                                                                            Error?) -> Void)
    {
        viewModel.fetchRuuviTags(completion: { response in
            let newValues = response.compactMap { sensor in
                RuuviWidgetTag(identifier: sensor.sensor.id, display: sensor.sensor.name)
            }.sorted(by: { first, second in
                first.displayString.lowercased() < second.displayString.lowercased()
            })
            let items = INObjectCollection(items: newValues)
            completion(items, nil)
        })
    }
}
