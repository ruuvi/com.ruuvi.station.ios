import UIKit
import RuuviLocalization

enum AirQualityState: String {
    case green
    case yellow
    case red

    var color: UIColor {
        switch self {
        case .green:
            return RuuviColor.green.color
        case .yellow:
            return RuuviColor.orangeColor.color
        case .red:
            return .red
        }
    }
}

struct AirQualityIndexHelper {
    static func calculateAirQuality(
        co2: Double?,
        pm25: Double?,
        voc: Double?,
        nox: Double?
    ) -> ( // swiftlint:disable:this large_tuple
        currentScore: Int,
        maxScore: Int,
        state: AirQualityState
    ) {
        func scorePpm(_ ppm: Double) -> Double {
            return max(0, (ppm - 12) * 2)
        }

        func scoreVoc(_ voc: Double) -> Double {
            return max(0, voc - 200)
        }

        func scoreNox(_ nox: Double) -> Double {
            return max(0, nox - 200)
        }

        func scoreCo2(_ co2: Double) -> Double {
            return max(0, (co2 - 600) / 10)
        }

        var distances = [Double]()

        if let co2 = co2 {
            distances.append(scoreCo2(co2))
        }
        if let pm25 = pm25 {
            distances.append(scorePpm(pm25))
        }
        if let voc = voc {
            distances.append(scoreVoc(voc))
        }
        if let nox = nox {
            distances.append(scoreNox(nox))
        }

        let maxScore = 100.0

        guard !distances.isEmpty else {
            return (
                currentScore: 0, maxScore: maxScore.intValue, state: .red
            )
        }

        let squaredSum = distances.reduce(0) { $0 + $1 * $1 }
        let meanSquared = squaredSum / Double(distances.count)
        let distance = sqrt(meanSquared)
        let currentScore = max(0, maxScore - distance)

        let state: AirQualityState
        switch currentScore {
        case 66...maxScore:
            state = .green
        case 33..<66:
            state = .yellow
        default:
            state = .red
        }

        return (
            currentScore: currentScore.intValue,
            maxScore: maxScore.intValue,
            state: state
        )
    }
}
