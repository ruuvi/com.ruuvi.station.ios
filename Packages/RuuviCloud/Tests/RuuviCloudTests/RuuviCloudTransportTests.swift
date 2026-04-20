@testable import RuuviCloud
import Foundation
import XCTest

final class RuuviCloudTransportTests: XCTestCase {
    func testURLSessionPublicInitializerConstructsWithoutImmediateRequests() {
        let sut = RuuviCloudApiURLSession(baseUrl: URL(string: "https://example.com/api")!)

        XCTAssertNotNil(sut)
    }

    func testQueryItemEncoderEncodesNestedArraysAndNilValues() throws {
        struct Payload: Encodable {
            let sensor: String
            let filters: Filters
            let values: [Int]

            struct Filters: Encodable {
                let enabled: Bool
                let note: String?
            }
        }

        let payload = Payload(
            sensor: "AA:BB:CC:11:22:33",
            filters: .init(enabled: true, note: nil),
            values: [3, 7]
        )

        let encoder = URLQueryItemEncoder()
        encoder.arrayIndexEncodingStrategy = .index

        let items = try encoder.encode(payload)

        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].name, "sensor")
        XCTAssertEqual(items[0].value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(items[1].name, "filters[enabled]")
        XCTAssertEqual(items[1].value, "true")
        XCTAssertEqual(items[2].name, "values[0]")
        XCTAssertEqual(items[2].value, "3")
        XCTAssertEqual(items[3].name, "values[1]")
        XCTAssertEqual(items[3].value, "7")
    }

    func testQueryItemEncoderRejectsNonGregorianDateComponents() {
        struct Payload: Encodable {
            let day: DateComponents
        }

        let encoder = URLQueryItemEncoder()
        let payload = Payload(
            day: DateComponents(
                calendar: Calendar(identifier: .buddhist),
                year: 2024,
                month: 6,
                day: 1
            )
        )

        XCTAssertThrowsError(try encoder.encode(payload)) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testQueryItemEncoderEncodesGregorianDateComponents() throws {
        struct Payload: Encodable {
            let day: DateComponents
        }

        let items = try URLQueryItemEncoder().encode(
            Payload(
                day: DateComponents(
                    calendar: Calendar(identifier: .gregorian),
                    year: 2024,
                    month: 6,
                    day: 1
                )
            )
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "day")
        XCTAssertEqual(items.first?.value, "2024-6-1")
    }

    func testQueryItemEncoderUsesCurrentCalendarForDateComponentsWithoutCalendar() throws {
        struct Payload: Encodable {
            let day: DateComponents
        }

        let items = try URLQueryItemEncoder().encode(
            Payload(
                day: DateComponents(
                    year: 2024,
                    month: 6,
                    day: 1
                )
            )
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "day")
        XCTAssertEqual(items.first?.value, "2024-6-1")
    }

    func testQueryItemEncoderFormUrlEncodingEscapesReservedCharacters() {
        let data = URLQueryItemEncoder.encodeToFormURLEncodedData(
            queryItems: [
                URLQueryItem(name: "email+value", value: "user+alias@example.com"),
                URLQueryItem(name: "sensor", value: "AA:BB:CC"),
            ]
        )

        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            "email%2Bvalue=user%2Balias%40example.com&sensor=AA%3ABB%3ACC"
        )
    }

    func testURLSessionBuildsGetRequestWithQueryHeadersAndDecodesResponse() async throws {
        var capturedRequest: URLRequest?
        let responseData = """
        {
          "result": "success",
          "data": {
            "email": "owner@example.com",
            "sensor": "AA:BB:CC:11:22:33"
          }
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { "42" },
            dataLoader: { request in
                capturedRequest = request
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            }
        )

        let response = try await sut.owner(
            RuuviCloudApiGetSensorsRequest(sensor: "AA:BB:CC:11:22:33"),
            authorization: "Bearer token"
        )

        XCTAssertEqual(response.email, "owner@example.com")
        XCTAssertEqual(response.sensor, "AA:BB:CC:11:22:33")
        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("Build_42/check") == true)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/api/check")
        XCTAssertEqual(components.queryItems?.first?.name, "sensor")
        XCTAssertEqual(components.queryItems?.first?.value, "AA:BB:CC:11:22:33")
        XCTAssertNil(request.httpBody)
    }

    func testURLSessionBuildsPostBodyAndMapsServer500ErrorsToRetryableFailures() async throws {
        var capturedRequest: URLRequest?
        let responseData = """
        {
          "result": "error",
          "error": "Internal error",
          "code": "ER_INTERNAL"
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                capturedRequest = request
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            }
        )

        do {
            _ = try await sut.claim(
                RuuviCloudApiClaimRequest(name: "Kitchen", sensor: "AA:BB:CC:11:22:33"),
                authorization: "Bearer token"
            )
            XCTFail("Expected retryable server failure")
        } catch let error as RuuviCloudApiError {
            guard case let .unexpectedHTTPStatusCodeShouldRetry(code) = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
            XCTAssertEqual(code, 500)
        }

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/claim")
        let body = try XCTUnwrap(request.httpBody)
        let payload = try JSONDecoder().decode(RuuviCloudApiClaimRequest.self, from: body)
        XCTAssertEqual(payload.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(payload.name, "Kitchen")
    }

    func testURLSessionReturnsConnectionErrorWhenOffline() async {
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { false },
            buildNumberProvider: { nil }
        )

        do {
            _ = try await sut.register(RuuviCloudApiRegisterRequest(email: "owner@example.com"))
            XCTFail("Expected connection error")
        } catch let error as RuuviCloudApiError {
            guard case .connection = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionPropagatesUserApiErrorForNon500Responses() async {
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 409,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (
                    Data(
                        """
                        {
                          "result": "error",
                          "error": "Already claimed",
                          "code": "ER_SENSOR_ALREADY_CLAIMED"
                        }
                        """.utf8
                    ),
                    response
                )
            }
        )

        do {
            _ = try await sut.claim(
                RuuviCloudApiClaimRequest(name: "Kitchen", sensor: "AA:BB:CC:11:22:33"),
                authorization: "Bearer token"
            )
            XCTFail("Expected API error")
        } catch let error as RuuviCloudApiError {
            guard case let .api(code) = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
            XCTAssertEqual(code, .erSensorAlreadyClaimed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionWrapsParsingFailures() async {
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data("not json".utf8), response)
            }
        )

        do {
            _ = try await sut.register(RuuviCloudApiRegisterRequest(email: "owner@example.com"))
            XCTFail("Expected parsing error")
        } catch let error as RuuviCloudApiError {
            guard case .parsing = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionRequestUsesInjectedTaskFactoryAndMapsNetworkingErrors() async {
        var capturedRequest: URLRequest?
        let task = CloudTaskSpy(taskIdentifier: 11)
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataTaskFactory: { request, completion in
                capturedRequest = request
                task.onResume = {
                    completion(nil, nil, CloudTransportError())
                }
                return task
            }
        )

        do {
            _ = try await sut.register(RuuviCloudApiRegisterRequest(email: "owner@example.com"))
            XCTFail("Expected networking error")
        } catch let error as RuuviCloudApiError {
            guard case .networking = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(task.resumeCount, 1)
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.url?.path, "/api/register")
    }

    func testURLSessionRequestUsesInjectedTaskFactoryAndFailsWithoutDataOrResponse() async {
        let task = CloudTaskSpy(taskIdentifier: 12)
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataTaskFactory: { _, completion in
                task.onResume = {
                    completion(nil, nil, nil)
                }
                return task
            }
        )

        do {
            _ = try await sut.verify(RuuviCloudApiVerifyRequest(token: "123456"))
            XCTFail("Expected missing response data failure")
        } catch let error as RuuviCloudApiError {
            guard case .failedToGetDataFromResponse = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(task.resumeCount, 1)
    }

    func testURLSessionUploadImageUsesRequestMimeTypeAndForwardsProgress() async throws {
        var postRequest: URLRequest?
        var uploadRequest: URLRequest?
        var uploadedData: Data?
        var progressValues: [Double] = []
        let responseData = """
        {
          "result": "success",
          "data": {
            "uploadURL": "https://uploads.example.com/sensor.png"
          }
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                postRequest = request
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            },
            uploadPerformer: { request, data, progress in
                uploadRequest = request
                uploadedData = data
                progress(0.25)
                progress(1.0)
                return Data("ok".utf8)
            }
        )
        let imageRequest = RuuviCloudApiSensorImageUploadRequest(
            sensor: "AA:BB:CC:11:22:33",
            action: .upload,
            mimeType: .png
        )

        let response = try await sut.uploadImage(
            imageRequest,
            imageData: Data([0x01, 0x02, 0x03]),
            authorization: "Bearer token",
            uploadProgress: { progressValues.append($0) }
        )

        XCTAssertEqual(response.uploadURL.absoluteString, "https://uploads.example.com/sensor.png")
        let capturedPostRequest = try XCTUnwrap(postRequest)
        XCTAssertEqual(capturedPostRequest.httpMethod, "POST")
        let postBody = try XCTUnwrap(capturedPostRequest.httpBody)
        let payload = try JSONDecoder().decode(RuuviCloudApiSensorImageUploadRequest.self, from: postBody)
        XCTAssertEqual(payload.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(payload.action, .upload)
        XCTAssertEqual(payload.mimeType, .png)

        let capturedUploadRequest = try XCTUnwrap(uploadRequest)
        XCTAssertEqual(capturedUploadRequest.url?.absoluteString, "https://uploads.example.com/sensor.png")
        XCTAssertEqual(capturedUploadRequest.httpMethod, "PUT")
        XCTAssertEqual(capturedUploadRequest.value(forHTTPHeaderField: "Content-Type"), MimeType.png.rawValue)
        XCTAssertEqual(uploadedData, Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(progressValues, [0.25, 1.0])
    }

    func testURLSessionUploadImageDefaultsMimeTypeToJpgWhenRequestOmitsType() async throws {
        var uploadRequest: URLRequest?
        let responseData = """
        {
          "result": "success",
          "data": {
            "uploadURL": "https://uploads.example.com/sensor.jpg"
          }
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            },
            uploadPerformer: { request, _, _ in
                uploadRequest = request
                return Data("ok".utf8)
            }
        )

        _ = try await sut.uploadImage(
            RuuviCloudApiSensorImageUploadRequest(
                sensor: "AA:BB:CC:11:22:33",
                action: .upload
            ),
            imageData: Data([0x01]),
            authorization: "Bearer token",
            uploadProgress: nil
        )

        XCTAssertEqual(uploadRequest?.value(forHTTPHeaderField: "Content-Type"), MimeType.jpg.rawValue)
    }

    func testURLSessionUploadUsesInjectedTaskFactoryReportsProgressAndIgnoresLateProgress() async throws {
        var uploadRequest: URLRequest?
        var uploadedData: Data?
        var uploadCompletion: RuuviCloudApiURLSession.UploadCompletion?
        var progressValues: [Double] = []
        let uploadStarted = expectation(description: "upload task created")
        let task = CloudTaskSpy(taskIdentifier: 42)
        let responseData = """
        {
          "result": "success",
          "data": {
            "uploadURL": "https://uploads.example.com/sensor.png"
          }
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            },
            uploadTaskFactory: { request, data, completion in
                uploadRequest = request
                uploadedData = data
                uploadCompletion = completion
                uploadStarted.fulfill()
                return task
            }
        )

        let imageTask = Task {
            try await sut.uploadImage(
                RuuviCloudApiSensorImageUploadRequest(
                    sensor: "AA:BB:CC:11:22:33",
                    action: .upload,
                    mimeType: .png
                ),
                imageData: Data([0x01, 0x02, 0x03, 0x04]),
                authorization: "Bearer token",
                uploadProgress: { progressValues.append($0) }
            )
        }

        await fulfillment(of: [uploadStarted], timeout: 1)

        XCTAssertEqual(task.resumeCount, 1)
        XCTAssertEqual(uploadedData, Data([0x01, 0x02, 0x03, 0x04]))
        XCTAssertEqual(uploadRequest?.value(forHTTPHeaderField: "Content-Type"), MimeType.png.rawValue)

        sut.handleUploadProgress(taskIdentifier: 42, totalBytesSent: 1, totalBytesExpectedToSend: 4)
        sut.handleUploadProgress(taskIdentifier: 42, totalBytesSent: 4, totalBytesExpectedToSend: 4)

        let request = try XCTUnwrap(uploadRequest)
        let response = HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        uploadCompletion?(Data("ok".utf8), response, nil)

        let uploadResponse = try await imageTask.value
        XCTAssertEqual(uploadResponse.uploadURL.absoluteString, "https://uploads.example.com/sensor.png")
        XCTAssertEqual(progressValues, [0.25, 1.0])

        sut.handleUploadProgress(taskIdentifier: 42, totalBytesSent: 2, totalBytesExpectedToSend: 4)
        XCTAssertEqual(progressValues, [0.25, 1.0])
    }

    func testURLSessionUploadUsesInjectedTaskFactoryMapsNetworkingErrors() async {
        let responseData = """
        {
          "result": "success",
          "data": {
            "uploadURL": "https://uploads.example.com/sensor.jpg"
          }
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            },
            uploadTaskFactory: { _, _, completion in
                CloudTaskSpy(
                    taskIdentifier: 43,
                    onResume: {
                        completion(nil, nil, CloudTransportError())
                    }
                )
            }
        )

        do {
            _ = try await sut.uploadImage(
                .init(sensor: "AA:BB:CC:11:22:33", action: .upload),
                imageData: Data([0x01]),
                authorization: "Bearer token",
                uploadProgress: nil
            )
            XCTFail("Expected networking error")
        } catch let error as RuuviCloudApiError {
            guard case .networking = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionUploadUsesInjectedTaskFactoryMapsUnexpectedStatusCode() async {
        let responseData = """
        {
          "result": "success",
          "data": {
            "uploadURL": "https://uploads.example.com/sensor.jpg"
          }
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            },
            uploadTaskFactory: { request, _, completion in
                return CloudTaskSpy(
                    taskIdentifier: 44,
                    onResume: {
                        completion(
                            nil,
                            HTTPURLResponse(
                                url: request.url!,
                                statusCode: 403,
                                httpVersion: nil,
                                headerFields: nil
                            ),
                            nil
                        )
                    }
                )
            }
        )

        do {
            _ = try await sut.uploadImage(
                .init(sensor: "AA:BB:CC:11:22:33", action: .upload),
                imageData: Data([0x01]),
                authorization: "Bearer token",
                uploadProgress: nil
            )
            XCTFail("Expected unexpected status code error")
        } catch let error as RuuviCloudApiError {
            guard case let .unexpectedHTTPStatusCode(code) = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
            XCTAssertEqual(code, 403)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionUploadUsesInjectedTaskFactoryFailsWithoutResponseData() async {
        let responseData = """
        {
          "result": "success",
          "data": {
            "uploadURL": "https://uploads.example.com/sensor.jpg"
          }
        }
        """.data(using: .utf8)!
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (responseData, response)
            },
            uploadTaskFactory: { _, _, completion in
                CloudTaskSpy(
                    taskIdentifier: 45,
                    onResume: {
                        completion(nil, nil, nil)
                    }
                )
            }
        )

        do {
            _ = try await sut.uploadImage(
                .init(sensor: "AA:BB:CC:11:22:33", action: .upload),
                imageData: Data([0x01]),
                authorization: "Bearer token",
                uploadProgress: nil
            )
            XCTFail("Expected failed to get data error")
        } catch let error as RuuviCloudApiError {
            guard case .failedToGetDataFromResponse = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionDefaultDataTaskUsesRegisteredProtocolAndDecodesResponse() async throws {
        let recorder = CloudRequestRecorder()
        CloudURLProtocolStub.start { request in
            recorder.append(request)
            return (
                Data(
                    wrappedSuccess("""
                    {
                      "email": "owner@example.com",
                      "accessToken": "token",
                      "newUser": false
                    }
                    """).utf8
                ),
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }
        defer { CloudURLProtocolStub.stop() }
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            urlProtocolClasses: [CloudURLProtocolStub.self]
        )

        let response = try await sut.verify(RuuviCloudApiVerifyRequest(token: "123456"))

        XCTAssertEqual(response.email, "owner@example.com")
        XCTAssertEqual(response.accessToken, "token")
        XCTAssertEqual(response.isNewUser, false)
        let request = try XCTUnwrap(recorder.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/verify")
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first?.name, "token")
        XCTAssertEqual(components.queryItems?.first?.value, "123456")
    }

    func testURLSessionDefaultDataTaskMapsProtocolFailureToNetworkingError() async {
        CloudURLProtocolStub.start { _ in
            throw CloudTransportError()
        }
        defer { CloudURLProtocolStub.stop() }
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            urlProtocolClasses: [CloudURLProtocolStub.self]
        )

        do {
            _ = try await sut.verify(RuuviCloudApiVerifyRequest(token: "123456"))
            XCTFail("Expected networking error")
        } catch let error as RuuviCloudApiError {
            guard case .networking = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionDefaultUploadTaskUsesRegisteredProtocol() async throws {
        let recorder = CloudRequestRecorder()
        CloudURLProtocolStub.start { request in
            if request.url?.path == "/api/upload" {
                return (
                    Data(
                        wrappedSuccess("""
                        {
                          "uploadURL": "https://uploads.example.com/sensor.png"
                        }
                        """).utf8
                    ),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            } else {
                recorder.append(request)
                return (
                    Data("uploaded".utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        }
        defer { CloudURLProtocolStub.stop() }
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            urlProtocolClasses: [CloudURLProtocolStub.self]
        )

        let response = try await sut.uploadImage(
            .init(
                sensor: "AA:BB:CC:11:22:33",
                action: .upload,
                mimeType: .png
            ),
            imageData: Data([0x01, 0x02]),
            authorization: "Bearer token",
            uploadProgress: nil
        )

        XCTAssertEqual(response.uploadURL.absoluteString, "https://uploads.example.com/sensor.png")
        let uploadRequest = try XCTUnwrap(recorder.first)
        XCTAssertEqual(uploadRequest.httpMethod, "PUT")
        XCTAssertEqual(uploadRequest.url?.host, "uploads.example.com")
        XCTAssertEqual(uploadRequest.value(forHTTPHeaderField: "Content-Type"), MimeType.png.rawValue)
    }

    func testQueryItemEncoderEncodesPrimitiveWidthsDatesUrlsAndSquareBracketArrays() throws {
        struct Payload: Encodable {
            let signed8: Int8
            let signed16: Int16
            let signed32: Int32
            let signed64: Int64
            let unsigned8: UInt8
            let unsigned16: UInt16
            let unsigned32: UInt32
            let unsigned64: UInt64
            let unsigned: UInt
            let ratio: Double
            let precise: Float
            let createdAt: Date
            let callback: URL
            let tags: [String]
        }

        let encoder = URLQueryItemEncoder()
        let payload = Payload(
            signed8: -8,
            signed16: -16,
            signed32: -32,
            signed64: -64,
            unsigned8: 8,
            unsigned16: 16,
            unsigned32: 32,
            unsigned64: 64,
            unsigned: 128,
            ratio: 1.5,
            precise: 2.5,
            createdAt: Date(timeIntervalSince1970: 0),
            callback: URL(string: "https://example.com/callback")!,
            tags: ["one", "two"]
        )

        let items = try encoder.encode(payload)

        XCTAssertEqual(items.map(\.name), [
            "signed8",
            "signed16",
            "signed32",
            "signed64",
            "unsigned8",
            "unsigned16",
            "unsigned32",
            "unsigned64",
            "unsigned",
            "ratio",
            "precise",
            "createdAt",
            "callback",
            "tags[]",
            "tags[]"
        ])
        XCTAssertEqual(items.map(\.value), [
            "-8",
            "-16",
            "-32",
            "-64",
            "8",
            "16",
            "32",
            "64",
            "128",
            "1.5",
            "2.5",
            "1970-01-01T00:00:00.000Z",
            "https://example.com/callback",
            "one",
            "two"
        ])
    }

    func testQueryItemEncoderSupportsNestedContainersNilAndSuperEncoders() throws {
        struct Payload: Encodable {
            enum CodingKeys: String, CodingKey {
                case nested
                case list
                case metadata
            }

            enum NestedKeys: String, CodingKey {
                case flag
                case note
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)

                var nested = container.nestedContainer(keyedBy: NestedKeys.self, forKey: .nested)
                try nested.encode(true, forKey: .flag)
                try nested.encodeNil(forKey: .note)

                var list = container.nestedUnkeyedContainer(forKey: .list)
                try list.encode("first")
                let nestedSuperEncoder = list.superEncoder()
                var nestedSuperValue = nestedSuperEncoder.singleValueContainer()
                try nestedSuperValue.encode("second")

                let metadataEncoder = container.superEncoder(forKey: .metadata)
                var metadataValue = metadataEncoder.singleValueContainer()
                try metadataValue.encode("meta")
            }
        }

        let items = try URLQueryItemEncoder().encode(Payload())

        XCTAssertEqual(items.map(\.name), [
            "nested[flag]",
            "nested[note]",
            "list[]",
            "metadata",
            "list[]"
        ])
        XCTAssertEqual(items.map(\.value), [
            "true",
            nil,
            "first",
            "meta",
            "second"
        ])
    }

    func testQueryItemEncoderSupportsSingleValueNilAndNestedUnkeyedArrays() throws {
        struct NestedListPayload: Encodable {
            enum CodingKeys: String, CodingKey {
                case list
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                var list = container.nestedUnkeyedContainer(forKey: .list)
                try list.encodeNil()
                var nested = list.nestedUnkeyedContainer()
                try nested.encode("deep")
            }
        }

        struct NilPayload: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }

        let nestedItems = try URLQueryItemEncoder().encode(NestedListPayload())
        let nilItems = try URLQueryItemEncoder().encode(NilPayload())

        XCTAssertEqual(nestedItems.count, 2)
        XCTAssertEqual(nestedItems[0].name, "list[]")
        XCTAssertNil(nestedItems[0].value)
        XCTAssertEqual(nestedItems[1].name, "list[]")
        XCTAssertEqual(nestedItems[1].value, "deep")
        XCTAssertEqual(nilItems.count, 1)
        XCTAssertEqual(nilItems.first?.name, "")
        XCTAssertNil(nilItems.first?.value)
    }

    func testQueryItemEncoderCoversSingleValuePrimitiveOverloadsAndExtraContainerPaths() throws {
        struct SingleValuePayload: Encodable {
            let encodeBody: (Encoder) throws -> Void

            func encode(to encoder: Encoder) throws {
                try encodeBody(encoder)
            }
        }

        struct KeyedSuperPayload: Encodable {
            enum CodingKeys: String, CodingKey {
                case unused
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                let superEncoder = container.superEncoder()
                var value = superEncoder.singleValueContainer()
                try value.encode("root")
            }
        }

        struct UnkeyedNestedPayload: Encodable {
            enum CodingKeys: String, CodingKey {
                case name
            }

            func encode(to encoder: Encoder) throws {
                var list = encoder.unkeyedContainer()
                var nested = list.nestedContainer(keyedBy: CodingKeys.self)
                try nested.encode("item", forKey: .name)
            }
        }

        func singleValueItem(
            _ encodeBody: @escaping (Encoder) throws -> Void
        ) throws -> URLQueryItem {
            try XCTUnwrap(URLQueryItemEncoder().encode(SingleValuePayload(encodeBody: encodeBody)).first)
        }

        let nilItem = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
        let boolItem = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(true)
        }
        let intItem = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(42)
        }
        let int8Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Int8(-8))
        }
        let int16Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Int16(-16))
        }
        let int32Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Int32(-32))
        }
        let int64Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Int64(-64))
        }
        let uintItem = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(UInt(64))
        }
        let uint8Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(UInt8(8))
        }
        let uint16Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(UInt16(16))
        }
        let uint32Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(UInt32(32))
        }
        let uint64Item = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(UInt64(64))
        }
        let floatItem = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Float(1.5))
        }
        let doubleItem = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Double(2.5))
        }
        let urlItem = try singleValueItem { encoder in
            var container = encoder.singleValueContainer()
            try container.encode(URL(string: "https://example.com/value")!)
        }
        let keyedSuperItem = try XCTUnwrap(URLQueryItemEncoder().encode(KeyedSuperPayload()).first)
        let unkeyedNestedItem = try XCTUnwrap(URLQueryItemEncoder().encode(UnkeyedNestedPayload()).first)

        XCTAssertEqual(nilItem.name, "")
        XCTAssertNil(nilItem.value)
        XCTAssertEqual(boolItem.value, "true")
        XCTAssertEqual(intItem.value, "42")
        XCTAssertEqual(int8Item.value, "-8")
        XCTAssertEqual(int16Item.value, "-16")
        XCTAssertEqual(int32Item.value, "-32")
        XCTAssertEqual(int64Item.value, "-64")
        XCTAssertEqual(uintItem.value, "64")
        XCTAssertEqual(uint8Item.value, "8")
        XCTAssertEqual(uint16Item.value, "16")
        XCTAssertEqual(uint32Item.value, "32")
        XCTAssertEqual(uint64Item.value, "64")
        XCTAssertEqual(floatItem.value, "1.5")
        XCTAssertEqual(doubleItem.value, "2.5")
        XCTAssertEqual(urlItem.value, "https://example.com/value")
        XCTAssertEqual(keyedSuperItem.name, "")
        XCTAssertEqual(keyedSuperItem.value, "root")
        XCTAssertEqual(unkeyedNestedItem.name, "[name]")
        XCTAssertEqual(unkeyedNestedItem.value, "item")
    }

    func testQueryItemEncoderExposesUserInfoAndUnkeyedContainerCount() throws {
        struct CountedListPayload: Encodable {
            func encode(to encoder: Encoder) throws {
                var list = encoder.unkeyedContainer()
                XCTAssertEqual(list.count, 0)
                try list.encode("first")
                XCTAssertEqual(list.count, 1)
                try list.encode("second")
                XCTAssertEqual(list.count, 2)
            }
        }

        let encoder = URLQueryItemEncoder()

        let items = try encoder.encode(CountedListPayload())

        XCTAssertTrue(encoder.userInfo.isEmpty)
        XCTAssertEqual(items.map(\.name), ["", ""])
        XCTAssertEqual(items.map(\.value), ["first", "second"])
    }

    func testQueryItemArrayElementKeyInitializersExposeIndexValues() throws {
        let stringKey = try XCTUnwrap(URLQueryItemArrayElementKey(stringValue: "12"))
        let intKey = try XCTUnwrap(URLQueryItemArrayElementKey(intValue: 7))

        XCTAssertEqual(stringKey.stringValue, "12")
        XCTAssertEqual(stringKey.intValue, 12)
        XCTAssertEqual(intKey.stringValue, "7")
        XCTAssertEqual(intKey.intValue, 7)
        XCTAssertNil(URLQueryItemArrayElementKey(stringValue: "not-a-number"))
    }

    func testURLSessionDataTaskFactorySuccessCoversRegisterAndClaimRoutes() async throws {
        var capturedRequests: [URLRequest] = []
        var nextTaskIdentifier = 100
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataTaskFactory: { request, completion in
                capturedRequests.append(request)
                defer { nextTaskIdentifier += 1 }
                return CloudTaskSpy(taskIdentifier: nextTaskIdentifier) {
                    switch request.url?.path {
                    case "/api/register":
                        completion(
                            Data(
                                wrappedSuccess("""
                                { "email": "owner@example.com" }
                                """).utf8
                            ),
                            HTTPURLResponse(
                                url: request.url!,
                                statusCode: 200,
                                httpVersion: nil,
                                headerFields: nil
                            ),
                            nil
                        )
                    case "/api/claim":
                        completion(
                            Data(
                                wrappedSuccess("""
                                { "sensor": "AA:BB:CC:11:22:33" }
                                """).utf8
                            ),
                            HTTPURLResponse(
                                url: request.url!,
                                statusCode: 200,
                                httpVersion: nil,
                                headerFields: nil
                            ),
                            nil
                        )
                    default:
                        completion(nil, nil, CloudTransportError())
                    }
                }
            }
        )

        let register = try await sut.register(.init(email: "owner@example.com"))
        let claim = try await sut.claim(
            .init(name: "Kitchen", sensor: "AA:BB:CC:11:22:33"),
            authorization: "Bearer token"
        )

        XCTAssertEqual(register.email, "owner@example.com")
        XCTAssertEqual(claim.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(capturedRequests.map { $0.url?.path }, ["/api/register", "/api/claim"])
        XCTAssertEqual(capturedRequests.map(\.httpMethod), ["POST", "POST"])
        XCTAssertEqual(capturedRequests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testURLSessionPublicInitializerWiresDefaultDependencies() {
        let previousReachability = Reachability.active
        defer {
            Reachability.active = previousReachability
        }
        Reachability.active = true
        let sut = RuuviCloudApiURLSession(baseUrl: URL(string: "https://example.com/api")!)

        let snapshot = sut.dependencySnapshotForTesting()

        XCTAssertTrue(snapshot.isReachable)
    }

    func testURLSessionMapsPostEncodingFailuresToBadParameters() async {
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { _ in
                XCTFail("Encoding should fail before transport")
                throw CloudTransportError()
            }
        )

        do {
            _ = try await sut.update(
                .init(
                    sensor: "AA:BB:CC:11:22:33",
                    name: "Kitchen",
                    offsetTemperature: .nan,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    timestamp: 1
                ),
                authorization: "Bearer token"
            )
            XCTFail("Expected bad parameters")
        } catch let error as RuuviCloudApiError {
            guard case .badParameters = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionMapsGetQueryEncodingFailuresToBadParameters() async {
        struct BadQuery: Encodable {
            let day = DateComponents(
                calendar: Calendar(identifier: .buddhist),
                year: 2024,
                month: 6,
                day: 1
            )
        }

        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { _ in
                XCTFail("Encoding should fail before transport")
                throw CloudTransportError()
            }
        )

        do {
            let _: RuuviCloudApiVerifyResponse = try await sut.getForTesting(model: BadQuery())
            XCTFail("Expected bad parameters")
        } catch let error as RuuviCloudApiError {
            guard case .badParameters = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testURLSessionGetForTestingDecodesSuccessfulResponse() async throws {
        struct Query: Encodable {
            let token: String
        }

        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                XCTAssertEqual(request.url?.path, "/api/verify")
                return makeResponse(
                    body: wrappedSuccess("""
                    {
                      "email": "owner@example.com",
                      "accessToken": "token",
                      "newUser": false
                    }
                    """),
                    for: request
                )
            }
        )

        let response: RuuviCloudApiVerifyResponse = try await sut.getForTesting(
            model: Query(token: "123456")
        )

        XCTAssertEqual(response.email, "owner@example.com")
        XCTAssertEqual(response.accessToken, "token")
    }

    func testURLSessionTaskDelegateForwardsProgressWithoutRegisteredHandler() {
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil }
        )
        var request = URLRequest(url: URL(string: "https://uploads.example.com/sensor.png")!)
        request.httpMethod = "PUT"
        let task = URLSession.shared.uploadTask(with: request, from: Data([0x01]))

        sut.urlSession(
            URLSession.shared,
            task: task,
            didSendBodyData: 1,
            totalBytesSent: 1,
            totalBytesExpectedToSend: 2
        )
        task.cancel()
    }

    func testURLSessionRoutesRemainingGetEndpointsAndDecodesResponses() async throws {
        var capturedRequests: [URLRequest] = []
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                capturedRequests.append(request)
                switch request.url?.path {
                case "/api/verify":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "email": "owner@example.com",
                          "accessToken": "token",
                          "newUser": true
                        }
                        """),
                        for: request
                    )
                case "/api/push-list":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "tokens": [{
                            "id": 7,
                            "lastAccessed": 1700000000,
                            "name": "Phone"
                          }]
                        }
                        """),
                        for: request
                    )
                case "/api/sensors":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "sensors": [{
                            "sensor": "AA:BB:CC:11:22:33",
                            "name": "Kitchen",
                            "picture": "https://example.com/image.png",
                            "public": true,
                            "canShare": true,
                            "sharedTo": ["friend@example.com"]
                          }]
                        }
                        """),
                        for: request
                    )
                case "/api/sensors-dense":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "sensors": [{
                            "sensor": "AA:BB:CC:11:22:33",
                            "owner": "owner@example.com",
                            "name": "Kitchen",
                            "picture": "https://example.com/image.png",
                            "public": false,
                            "canShare": true,
                            "measurements": [],
                            "alerts": []
                          }]
                        }
                        """),
                        for: request
                    )
                case "/api/user":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "email": "owner@example.com",
                          "sensors": []
                        }
                        """),
                        for: request
                    )
                case "/api/get":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "sensor": "AA:BB:CC:11:22:33",
                          "total": 1,
                          "name": "Kitchen",
                          "measurements": []
                        }
                        """),
                        for: request
                    )
                case "/api/settings":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "settings": {
                            "PROFILE_LANGUAGE_CODE": "fi"
                          }
                        }
                        """),
                        for: request
                    )
                case "/api/alerts":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "sensors": []
                        }
                        """),
                        for: request
                    )
                default:
                    XCTFail("Unexpected request path: \(String(describing: request.url?.path))")
                    return makeResponse(body: wrappedSuccess("{}"), for: request)
                }
            }
        )

        let verify = try await sut.verify(RuuviCloudApiVerifyRequest(token: "123456"))
        let tokens = try await sut.listPNTokens(.init(), authorization: "Bearer token")
        let sensors = try await sut.sensors(
            .init(sensor: "AA:BB:CC:11:22:33"),
            authorization: "Bearer token"
        )
        let dense = try await sut.sensorsDense(
            .init(
                sensor: "AA:BB:CC:11:22:33",
                measurements: true,
                sharedToMe: false,
                sharedToOthers: true,
                alerts: true,
                settings: false
            ),
            authorization: "Bearer token"
        )
        let user = try await sut.user(authorization: "Bearer token")
        let records = try await sut.getSensorData(
            .init(sensor: "AA:BB:CC:11:22:33", until: 200, since: 100, limit: nil, sort: .asc),
            authorization: "Bearer token"
        )
        let settings = try await sut.getSettings(.init(), authorization: "Bearer token")
        let alerts = try await sut.getAlerts(
            {
                var request = RuuviCloudApiGetAlertsRequest()
                request.sensor = "AA:BB:CC:11:22:33"
                return request
            }(),
            authorization: "Bearer token"
        )

        XCTAssertEqual(verify.email, "owner@example.com")
        XCTAssertEqual(verify.accessToken, "token")
        XCTAssertEqual(tokens.tokens?.first?.id, 7)
        XCTAssertEqual(sensors.sensors?.first?.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(dense.sensors?.first?.owner, "owner@example.com")
        XCTAssertEqual(user.email, "owner@example.com")
        XCTAssertEqual(records.name, "Kitchen")
        XCTAssertEqual(settings.settings?.profileLanguageCode, "fi")
        XCTAssertEqual(alerts.sensors?.count, 0)

        let methodsByPath = capturedRequests.reduce(into: [String: String]()) { result, request in
            if let path = request.url?.path {
                result[path] = request.httpMethod ?? ""
            }
        }
        XCTAssertEqual(methodsByPath["/api/verify"], "GET")
        XCTAssertEqual(methodsByPath["/api/push-list"], "GET")
        XCTAssertEqual(methodsByPath["/api/sensors"], "GET")
        XCTAssertEqual(methodsByPath["/api/sensors-dense"], "GET")
        XCTAssertEqual(methodsByPath["/api/user"], "GET")
        XCTAssertEqual(methodsByPath["/api/get"], "GET")
        XCTAssertEqual(methodsByPath["/api/settings"], "GET")
        XCTAssertEqual(methodsByPath["/api/alerts"], "GET")

        let verifyComponents = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(capturedRequests[0].url), resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(verifyComponents.queryItems?.first?.name, "token")
        XCTAssertEqual(verifyComponents.queryItems?.first?.value, "123456")

        let denseRequest = try XCTUnwrap(capturedRequests.first { $0.url?.path == "/api/sensors-dense" })
        let denseComponents = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(denseRequest.url), resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: denseComponents.queryItems?.map { ($0.name, $0.value) } ?? []),
            [
                "sensor": "AA:BB:CC:11:22:33",
                "measurements": "true",
                "sharedToMe": "false",
                "sharedToOthers": "true",
                "alerts": "true",
                "settings": "false"
            ]
        )
    }

    func testURLSessionRoutesRemainingPostEndpointsAndDecodesResponses() async throws {
        var capturedRequests: [URLRequest] = []
        let sut = RuuviCloudApiURLSession(
            baseUrl: URL(string: "https://example.com/api")!,
            isReachable: { true },
            buildNumberProvider: { nil },
            dataLoader: { request in
                capturedRequests.append(request)
                switch request.url?.path {
                case "/api/request-delete":
                    return makeResponse(
                        body: wrappedSuccess("""
                        { "email": "owner@example.com" }
                        """),
                        for: request
                    )
                case "/api/push-register":
                    return makeResponse(
                        body: wrappedSuccess("""
                        { "id": 7, "lastAccessed": 1700000000, "name": "Phone" }
                        """),
                        for: request
                    )
                case "/api/push-unregister":
                    return makeResponse(body: wrappedSuccess("{}"), for: request)
                case "/api/contest-sensor":
                    return makeResponse(
                        body: wrappedSuccess("""
                        { "sensor": "AA:BB:CC:11:22:33" }
                        """),
                        for: request
                    )
                case "/api/unclaim":
                    return makeResponse(body: wrappedSuccess("{}"), for: request)
                case "/api/share":
                    return makeResponse(
                        body: wrappedSuccess("""
                        { "sensor": "AA:BB:CC:11:22:33", "invited": true }
                        """),
                        for: request
                    )
                case "/api/unshare":
                    return makeResponse(body: wrappedSuccess("{}"), for: request)
                case "/api/update":
                    return makeResponse(
                        body: wrappedSuccess("""
                        { "name": "Renamed" }
                        """),
                        for: request
                    )
                case "/api/upload":
                    return makeResponse(body: wrappedSuccess("{}"), for: request)
                case "/api/settings":
                    return makeResponse(
                        body: wrappedSuccess("""
                        { "action": "saved" }
                        """),
                        for: request
                    )
                case "/api/sensor-settings":
                    return makeResponse(
                        body: wrappedSuccess("""
                        {
                          "result": "success",
                          "data": { "action": "saved" }
                        }
                        """),
                        for: request
                    )
                case "/api/alerts":
                    return makeResponse(
                        body: wrappedSuccess("""
                        { "action": "saved" }
                        """),
                        for: request
                    )
                default:
                    XCTFail("Unexpected request path: \(String(describing: request.url?.path))")
                    return makeResponse(body: wrappedSuccess("{}"), for: request)
                }
            }
        )

        let deleteAccount = try await sut.deleteAccount(
            .init(email: "owner@example.com"),
            authorization: "Bearer token"
        )
        let registeredToken = try await sut.registerPNToken(
            .init(token: "push-token", type: "ios", name: "Phone", data: "payload", params: ["env": "dev"]),
            authorization: "Bearer token"
        )
        let unregisteredToken = try await sut.unregisterPNToken(
            .init(token: "push-token", id: nil),
            authorization: nil
        )
        let contest = try await sut.contest(
            .init(sensor: "AA:BB:CC:11:22:33", secret: "secret"),
            authorization: "Bearer token"
        )
        let unclaim = try await sut.unclaim(
            .init(sensor: "AA:BB:CC:11:22:33", deleteData: true),
            authorization: "Bearer token"
        )
        let share = try await sut.share(
            .init(user: "friend@example.com", sensor: "AA:BB:CC:11:22:33"),
            authorization: "Bearer token"
        )
        let unshare = try await sut.unshare(
            .init(user: "friend@example.com", sensor: "AA:BB:CC:11:22:33"),
            authorization: "Bearer token"
        )
        let update = try await sut.update(
            .init(
                sensor: "AA:BB:CC:11:22:33",
                name: "Renamed",
                offsetTemperature: 1.5,
                offsetHumidity: 0.25,
                offsetPressure: 2.0,
                timestamp: 1
            ),
            authorization: "Bearer token"
        )
        let resetImage = try await sut.resetImage(
            .init(sensor: "AA:BB:CC:11:22:33", action: .reset),
            authorization: "Bearer token"
        )
        let postSetting = try await sut.postSetting(
            .init(name: .profileLanguageCode, value: "fi", timestamp: 2),
            authorization: "Bearer token"
        )
        let postSensorSettings = try await sut.postSensorSettings(
            .init(
                sensor: "AA:BB:CC:11:22:33",
                type: ["description"],
                value: ["Kitchen"],
                timestamp: 3
            ),
            authorization: "Bearer token"
        )
        let postAlert = try await sut.postAlert(
            .init(
                sensor: "AA:BB:CC:11:22:33",
                enabled: true,
                type: .temperature,
                min: -5,
                max: 20,
                description: "Room",
                counter: 1,
                delay: 0,
                timestamp: 4
            ),
            authorization: "Bearer token"
        )

        XCTAssertEqual(deleteAccount.email, "owner@example.com")
        XCTAssertEqual(registeredToken.id, 7)
        XCTAssertNotNil(unregisteredToken)
        XCTAssertEqual(contest.sensor, "AA:BB:CC:11:22:33")
        XCTAssertNotNil(unclaim)
        XCTAssertEqual(share.invited, true)
        XCTAssertNotNil(unshare)
        XCTAssertEqual(update.name, "Renamed")
        XCTAssertNotNil(resetImage)
        XCTAssertEqual(postSetting.action, "saved")
        XCTAssertEqual(postSensorSettings.result, "success")
        XCTAssertEqual(postSensorSettings.data?.action, "saved")
        XCTAssertEqual(postAlert.action, "saved")

        XCTAssertTrue(capturedRequests.allSatisfy { $0.httpMethod == "POST" })
        let deleteRequest = try XCTUnwrap(capturedRequests.first { $0.url?.path == "/api/request-delete" })
        let deletePayload = try jsonBody(from: deleteRequest)
        XCTAssertEqual(deletePayload["email"] as? String, "owner@example.com")

        let registerTokenRequest = try XCTUnwrap(capturedRequests.first { $0.url?.path == "/api/push-register" })
        let registerTokenPayload = try jsonBody(from: registerTokenRequest)
        XCTAssertEqual(registerTokenPayload["token"] as? String, "push-token")
        XCTAssertEqual(registerTokenRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token")

        let unregisterTokenRequest = try XCTUnwrap(
            capturedRequests.first { $0.url?.path == "/api/push-unregister" }
        )
        XCTAssertNil(unregisterTokenRequest.value(forHTTPHeaderField: "Authorization"))

        let updateRequest = try XCTUnwrap(capturedRequests.first { $0.url?.path == "/api/update" })
        let updatePayload = try jsonBody(from: updateRequest)
        XCTAssertEqual(updatePayload["name"] as? String, "Renamed")
        XCTAssertEqual(updatePayload["sensor"] as? String, "AA:BB:CC:11:22:33")

        let sensorSettingsRequest = try XCTUnwrap(
            capturedRequests.first { $0.url?.path == "/api/sensor-settings" }
        )
        let sensorSettingsPayload = try jsonBody(from: sensorSettingsRequest)
        XCTAssertEqual(sensorSettingsPayload["type"] as? [String], ["description"])
        XCTAssertEqual(sensorSettingsPayload["value"] as? [String], ["Kitchen"])

        let alertRequest = try XCTUnwrap(capturedRequests.first { $0.url?.path == "/api/alerts" })
        let alertPayload = try jsonBody(from: alertRequest)
        XCTAssertEqual(alertPayload["type"] as? String, "temperature")
        XCTAssertEqual(alertPayload["description"] as? String, "Room")
    }

    func testFactoryCreatesURLSessionBackedApi() {
        let api = RuuviCloudApiFactoryURLSession().create(baseUrl: URL(string: "https://example.com")!)

        XCTAssertTrue(api is RuuviCloudApiURLSession)
    }
}

private func wrappedSuccess(_ data: String) -> String {
    """
    {
      "result": "success",
      "data": \(data)
    }
    """
}

private func makeResponse(body: String, for request: URLRequest) -> (Data, URLResponse) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    return (Data(body.utf8), response)
}

private func jsonBody(from request: URLRequest) throws -> [String: Any] {
    let body = try XCTUnwrap(request.httpBody)
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private struct CloudTransportError: Error {}

private final class CloudRequestRecorder {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var first: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return storage.first
    }

    func append(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(request)
    }
}

private final class CloudURLProtocolStub: URLProtocol {
    typealias Handler = (URLRequest) throws -> (Data, URLResponse)

    private static let lock = NSLock()
    private static var handler: Handler?

    static func start(handler: @escaping Handler) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    static func stop() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler: Handler?
        Self.lock.lock()
        handler = Self.handler
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: CloudTransportError())
            return
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class CloudTaskSpy: RuuviCloudTasking {
    let taskIdentifier: Int
    var resumeCount = 0
    var onResume: (() -> Void)?

    init(taskIdentifier: Int, onResume: (() -> Void)? = nil) {
        self.taskIdentifier = taskIdentifier
        self.onResume = onResume
    }

    func resume() {
        resumeCount += 1
        onResume?()
    }
}
