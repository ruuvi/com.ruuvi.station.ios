import Intents

class IntentHandler: INExtension, RuuviTagSelectionIntentHandling {
    private let viewModel = WidgetViewModel()
    func provideRuuviWidgetTagOptionsCollection(for intent: RuuviTagSelectionIntent,
                                                with completion: @escaping (INObjectCollection<RuuviWidgetTag>?,
                                                                                  Error?) -> Void) {
        viewModel.fetchRuuviTags(completion: { sensors in
            let newValues = sensors.compactMap({ sensor in
                RuuviWidgetTag(identifier: sensor.id, display: sensor.name)
            }).sorted(by: { first, second in
                return first.displayString.lowercased() < second.displayString.lowercased()
            })
            let items = INObjectCollection(items: newValues)
            completion(items, nil)
        })
    }
}
