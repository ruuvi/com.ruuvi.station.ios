import RuuviOntology

protocol NewCardsMeasurementViewOutput: AnyObject {
    func viewWillAppear(sender: NewCardsMeasurementViewController)
    func viewDidScroll(
        to index: Int,
        sender: NewCardsMeasurementViewController
    )
}
