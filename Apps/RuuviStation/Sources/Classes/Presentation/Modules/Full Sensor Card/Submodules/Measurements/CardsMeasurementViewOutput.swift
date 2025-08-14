import RuuviOntology

protocol CardsMeasurementViewOutput: AnyObject {
    func viewWillAppear(sender: CardsMeasurementViewController)
    func viewDidScroll(
        to index: Int,
        sender: CardsMeasurementViewController
    )
}
