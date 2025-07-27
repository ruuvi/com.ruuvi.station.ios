import Foundation
import RuuviOntology

protocol CardsGraphPresenterInput: CardsPresenterInput {
    func configure(sensorSettings: SensorSettings?)
    func configure(output: CardsGraphPresenterOutput?)
}
