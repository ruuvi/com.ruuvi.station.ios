import Foundation

actor WatchCloudService {

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case notAuthorized
        case networkError(Error)
        case badResponse(Int)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:          return "Not authorized"
            case .networkError(let e):    return "Network: \(e.localizedDescription)"
            case .badResponse(let code):  return "HTTP \(code)"
            case .decodingError(let e):   return "Decode: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Constants

    private static let productionURL = "https://network.ruuvi.com"
    private static let developmentURL = "https://testnet.ruuvi.com"

    // MARK: - API key persistence

    static func storedApiKey() -> String? {
        UserDefaults(suiteName: WatchSharedDefaults.suiteName)?
            .string(forKey: WatchSharedDefaults.watchApiKeyKey)
    }

    static func storeApiKey(_ key: String?) {
        let ud = UserDefaults(suiteName: WatchSharedDefaults.suiteName)
        if let key {
            ud?.set(key, forKey: WatchSharedDefaults.watchApiKeyKey)
        } else {
            ud?.removeObject(forKey: WatchSharedDefaults.watchApiKeyKey)
        }
    }

    // MARK: - Fetch

    func fetchSensors() async throws -> [WatchSensor] {
        guard let apiKey = WatchCloudService.storedApiKey(), !apiKey.isEmpty else {
            throw ServiceError.notAuthorized
        }

        let ud = UserDefaults(suiteName: WatchSharedDefaults.suiteName)
        let base = (ud?.bool(forKey: WatchSharedDefaults.useDevServerKey) ?? false)
            ? WatchCloudService.developmentURL
            : WatchCloudService.productionURL

        guard var components = URLComponents(string: "\(base)/sensors-dense") else {
            throw ServiceError.notAuthorized
        }
        components.queryItems = [
            URLQueryItem(name: "measurements", value: "true"),
            URLQueryItem(name: "sharedToMe",   value: "true"),
        ]
        guard let url = components.url else { throw ServiceError.notAuthorized }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ServiceError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw ServiceError.badResponse(http.statusCode)  // status code shown in error message
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(SensorsDenseResponse.self, from: data)
            return decoded.data?.sensors?.compactMap { Self.mapSensor($0) } ?? []
        } catch {
            throw ServiceError.decodingError(error)
        }
    }

    // MARK: - Mapping

    private static func mapSensor(_ raw: RawSensor) -> WatchSensor? {
        guard let id = raw.sensor else { return nil }

        let latestRecord = raw.measurements?.first
        let measurement = latestRecord.flatMap { decodeMeasurement(from: $0) }
        let updatedAt = latestRecord?.timestamp.map { Date(timeIntervalSince1970: $0) }

        let displayOrderCodes  = raw.settings?.displayOrderCodes ?? []
        let defaultDisplayOrder = raw.settings?.defaultDisplayOrder ?? true

        return WatchSensor(
            id: id,
            name: raw.name ?? id,
            version: measurement?.version,
            temperature: measurement?.temperature,
            humidity: measurement?.humidity,
            pressure: measurement?.pressure,
            voltage: measurement?.voltage,
            txPower: measurement?.txPower,
            accelerationX: measurement?.accelerationX,
            accelerationY: measurement?.accelerationY,
            accelerationZ: measurement?.accelerationZ,
            movementCounter: measurement?.movementCounter,
            measurementSequenceNumber: measurement?.measurementSequenceNumber,
            rssi: latestRecord?.rssi,
            pm1: measurement?.pm1,
            pm25: measurement?.pm25,
            pm4: measurement?.pm4,
            pm10: measurement?.pm10,
            co2: measurement?.co2,
            voc: measurement?.voc,
            nox: measurement?.nox,
            luminosity: measurement?.luminosity,
            soundInstant: measurement?.soundInstant,
            soundAverage: measurement?.soundAverage,
            soundPeak: measurement?.soundPeak,
            updatedAt: updatedAt,
            displayOrderCodes: displayOrderCodes,
            defaultDisplayOrder: defaultDisplayOrder
        )
    }

    private static func decodeMeasurement(
        from rawMeasurement: RawMeasurement
    ) -> DecodedMeasurement? {
        guard let payload = rawMeasurement.data,
              let df5 = RuuviDF5Parser.parse(hexString: payload)
        else {
            return nil
        }

        return DecodedMeasurement(
            version: 5,
            temperature: df5.temperature,
            humidity: df5.humidity,
            pressure: df5.pressure,
            voltage: df5.voltage,
            txPower: df5.txPower,
            accelerationX: df5.accelerationX,
            accelerationY: df5.accelerationY,
            accelerationZ: df5.accelerationZ,
            movementCounter: df5.movementCounter,
            measurementSequenceNumber: df5.measurementSequenceNumber,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminosity: nil,
            soundInstant: nil,
            soundAverage: nil,
            soundPeak: nil
        )
    }
}

// MARK: - Response models

private struct SensorsDenseResponse: Decodable {
    let status: String?
    let data: SensorsData?

    struct SensorsData: Decodable {
        let sensors: [RawSensor]?
    }
}

private struct RawSensor: Decodable {
    let sensor: String?
    let name: String?
    let measurements: [RawMeasurement]?
    let settings: RawSensorSettings?
}

private struct RawMeasurement: Decodable {
    let data: String?
    let rssi: Int?
    let timestamp: TimeInterval?
}

private struct RawSensorSettings: Decodable {
    let displayOrderCodes: [String]?
    let defaultDisplayOrder: Bool?

    private enum CodingKeys: String, CodingKey {
        case displayOrder = "displayOrder"
        case defaultDisplayOrder = "defaultDisplayOrder"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let codes = try? container.decode([String].self, forKey: .displayOrder) {
            displayOrderCodes = codes
        } else if let raw = try? container.decode(String.self, forKey: .displayOrder) {
            displayOrderCodes = Self.parseDisplayOrder(raw)
        } else {
            displayOrderCodes = nil
        }

        if let flag = try? container.decode(Bool.self, forKey: .defaultDisplayOrder) {
            defaultDisplayOrder = flag
        } else if let rawFlag = try? container.decode(String.self, forKey: .defaultDisplayOrder) {
            defaultDisplayOrder = Self.parseBoolean(rawFlag)
        } else {
            defaultDisplayOrder = nil
        }
    }

    private static func parseDisplayOrder(_ raw: String) -> [String]? {
        guard let data = raw.data(using: .utf8) else {
            return nil
        }
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let decoded = jsonObject as? [String] {
            return decoded
        }
        return nil
    }

    private static func parseBoolean(_ raw: String) -> Bool? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }
}

private struct DecodedMeasurement {
    let version: Int?
    let temperature: Double?
    let humidity: Double?
    let pressure: Double?
    let voltage: Double?
    let txPower: Int?
    let accelerationX: Double?
    let accelerationY: Double?
    let accelerationZ: Double?
    let movementCounter: Int?
    let measurementSequenceNumber: Int?
    let pm1: Double?
    let pm25: Double?
    let pm4: Double?
    let pm10: Double?
    let co2: Double?
    let voc: Double?
    let nox: Double?
    let luminosity: Double?
    let soundInstant: Double?
    let soundAverage: Double?
    let soundPeak: Double?
}
