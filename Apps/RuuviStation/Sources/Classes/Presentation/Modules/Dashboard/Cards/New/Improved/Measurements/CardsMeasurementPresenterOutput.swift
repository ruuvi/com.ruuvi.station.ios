import RuuviOntology

protocol CardsMeasurementPresenterOutput: AnyObject {
    func measurementPresenter(
        _ presenter: NewCardsMeasurementPresenter,
        didNavigateToIndex index: Int
    )
}
