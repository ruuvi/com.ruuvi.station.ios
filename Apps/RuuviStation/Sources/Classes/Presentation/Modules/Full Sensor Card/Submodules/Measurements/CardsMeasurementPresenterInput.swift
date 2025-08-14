import RuuviOntology

protocol CardsMeasurementPresenterInput: CardsPresenterInput {
    func configure(
        output: CardsMeasurementPresenterOutput?
    )
}
