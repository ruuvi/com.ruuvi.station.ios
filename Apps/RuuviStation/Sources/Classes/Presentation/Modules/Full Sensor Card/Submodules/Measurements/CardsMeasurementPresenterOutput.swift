import RuuviOntology

protocol CardsMeasurementPresenterOutput: AnyObject {
    func measurementPresenter(
        _ presenter: CardsMeasurementPresenter,
        didNavigateToIndex index: Int
    )
}
