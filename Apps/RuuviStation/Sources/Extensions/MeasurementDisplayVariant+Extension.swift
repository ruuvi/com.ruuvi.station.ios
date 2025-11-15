import RuuviOntology

extension MeasurementDisplayVariant {
    func baseTypeEquals(_ other: MeasurementType) -> Bool {
        type.isSameCase(as: other)
    }
}
