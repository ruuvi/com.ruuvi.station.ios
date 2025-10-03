import Foundation
import RuuviLocalization
import RuuviOntology

public struct BeaverAdviceHelper {
    // MARK: - AQI Advice String Arrays

    private static let aqiExcellent = [
        RuuviLocalization.aqiAdviceExcellent1,
        RuuviLocalization.aqiAdviceExcellent2,
        RuuviLocalization.aqiAdviceExcellent3,
        RuuviLocalization.aqiAdviceExcellent4,
        RuuviLocalization.aqiAdviceExcellent5,
        RuuviLocalization.aqiAdviceExcellent6,
    ]

    private static let aqiGood = [
        RuuviLocalization.aqiAdviceGood1,
        RuuviLocalization.aqiAdviceGood2,
        RuuviLocalization.aqiAdviceGood3,
        RuuviLocalization.aqiAdviceGood4,
        RuuviLocalization.aqiAdviceGood5,
        RuuviLocalization.aqiAdviceGood6,
    ]

    private static let aqiFair = [
        RuuviLocalization.aqiAdviceFair1,
        RuuviLocalization.aqiAdviceFair2,
        RuuviLocalization.aqiAdviceFair3,
        RuuviLocalization.aqiAdviceFair4,
        RuuviLocalization.aqiAdviceFair5,
        RuuviLocalization.aqiAdviceFair6,
    ]

    private static let aqiPoor = [
        RuuviLocalization.aqiAdvicePoor1,
        RuuviLocalization.aqiAdvicePoor2,
        RuuviLocalization.aqiAdvicePoor3,
        RuuviLocalization.aqiAdvicePoor4,
        RuuviLocalization.aqiAdvicePoor5,
        RuuviLocalization.aqiAdvicePoor6,
    ]

    private static let aqiVeryPoor = [
        RuuviLocalization.aqiAdviceVerypoor1,
        RuuviLocalization.aqiAdviceVerypoor2,
        RuuviLocalization.aqiAdviceVerypoor3,
        RuuviLocalization.aqiAdviceVerypoor4,
        RuuviLocalization.aqiAdviceVerypoor5,
        RuuviLocalization.aqiAdviceVerypoor6,
    ]

    // MARK: - Helper Functions

    private static func aqiSet(
        for state: MeasurementQualityState
    ) -> [String] {
        switch state {
        case .excellent: return aqiExcellent
        case .good: return aqiGood
        case .fair: return aqiFair
        case .poor: return aqiPoor
        case .veryPoor: return aqiVeryPoor
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func co2PmAdvice(
        co2: MeasurementQualityState?,
        pm: MeasurementQualityState?
    ) -> String? {
        guard let co2 = co2 else { return nil }

        switch co2 {
        case .excellent:
            switch pm {
            case .good:
                return RuuviLocalization.aqiAdviceCo2ExcellentPmGood
            case .fair:
                return RuuviLocalization.aqiAdviceCo2ExcellentPmFair
            case .poor:
                return RuuviLocalization.aqiAdviceCo2ExcellentPmPoor
            case .veryPoor:
                return RuuviLocalization
                    .aqiAdviceCo2ExcellentPmVerypoor
            default:
                return nil
            }

        case .good:
            switch pm {
            case .excellent:
                return RuuviLocalization.aqiAdviceCo2GoodPmExcellent
            case .good:
                return RuuviLocalization.aqiAdviceCo2GoodPmGood
            case .fair:
                return RuuviLocalization.aqiAdviceCo2GoodPmFair
            case .poor:
                return RuuviLocalization.aqiAdviceCo2GoodPmPoor
            case .veryPoor:
                return RuuviLocalization.aqiAdviceCo2GoodPmVerypoor
            default:
                return nil
            }

        case .fair:
            switch pm {
            case .excellent:
                return RuuviLocalization.aqiAdviceCo2FairPmExcellent
            case .good:
                return RuuviLocalization.aqiAdviceCo2FairPmGood
            case .fair:
                return RuuviLocalization.aqiAdviceCo2FairPmFair
            case .poor:
                return RuuviLocalization.aqiAdviceCo2FairPmPoor
            case .veryPoor:
                return RuuviLocalization.aqiAdviceCo2FairPmVerypoor
            default:
                return nil
            }

        case .poor:
            switch pm {
            case .excellent:
                return RuuviLocalization.aqiAdviceCo2PoorPmExcellent
            case .good:
                return RuuviLocalization.aqiAdviceCo2PoorPmGood
            case .fair:
                return RuuviLocalization.aqiAdviceCo2PoorPmFair
            case .poor:
                return RuuviLocalization.aqiAdviceCo2PoorPmPoor
            case .veryPoor:
                return RuuviLocalization.aqiAdviceCo2PoorPmVerypoor
            default:
                return nil
            }

        case .veryPoor:
            switch pm {
            case .excellent:
                return RuuviLocalization
                    .aqiAdviceCo2VerypoorPmExcellent
            case .good:
                return RuuviLocalization.aqiAdviceCo2VerypoorPmGood
            case .fair:
                return RuuviLocalization.aqiAdviceCo2VerypoorPmFair
            case .poor:
                return RuuviLocalization.aqiAdviceCo2VerypoorPmPoor
            case .veryPoor:
                return RuuviLocalization
                    .aqiAdviceCo2VerypoorPmVerypoor
            default:
                return nil
            }
        }
    }

    // MARK: - Public API

    static func getBeaverAdvice(
        aqiQuality: MeasurementQualityState,
        co2Quality: MeasurementQualityState?,
        pm25Quality: MeasurementQualityState?
    ) -> String {
        let aqiAdvices = aqiSet(for: aqiQuality)
        let randomAdvice = aqiAdvices.randomElement() ?? aqiAdvices[0]

        if let additionalAdvice = co2PmAdvice(
            co2: co2Quality,
            pm: pm25Quality
        ) {
            return randomAdvice + "\n\n" + additionalAdvice
        }

        return randomAdvice
    }
}
