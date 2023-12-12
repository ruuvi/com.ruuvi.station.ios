import Humidity
import Nimble
import Quick
import XCTest

// swiftlint:disable file_length
@testable import station
// swiftlint:disable:next type_body_length
class AlertServiceSpec: QuickSpec {
    let notificationWaitTimeout: DispatchTimeInterval = .milliseconds(200)
    // swiftlint:disable:next function_body_length
    override func spec() {
        let alertService = AlertServiceImpl()
        alertService.alertPersistence = AlertPersistenceUserDefaults()

        let localNotificationManager = MockLocalNotificationsManager()
        alertService.localNotificationsManager = localNotificationManager

        alertService.calibrationService = MockCalibrationService()
        var uuid: String = UUID().uuidString
        var randomDouble = Double.random(in: -100 ... 100)
        var randomPercentDouble = Double.random(in: 10 ... 90)
        let type: AlertType = .connection
        beforeEach {
            randomPercentDouble = Double.random(in: 10 ... 90)
            randomDouble = Double.random(in: -100 ... 100)
            uuid = UUID().uuidString
        }

        // MARK: - Registration

        describe("Registration") {
            context("when register") {
                it("must has registration") {
                    alertService.register(type: type, for: uuid)
                    expect(alertService.hasRegistrations(for: uuid)).to(beTrue())
                }
                it("must be isOn") {
                    alertService.register(type: type, for: uuid)
                    expect(alertService.isOn(type: type, for: uuid)).to(beTrue())
                }
                it("must return type if it contains in persistence") {
                    alertService.register(type: type, for: uuid)
                    expect(alertService.alert(for: uuid, of: type)).notTo(beNil())
                }
                it("must send notification AlertServiceAlertDidChange with userInfo") {
                    expect {
                        alertService.register(type: type, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when unregister") {
                it("must not has registration") {
                    alertService.unregister(type: type, for: uuid)
                    expect(alertService.hasRegistrations(for: uuid)).to(beFalse())
                }
                it("must not be isOn") {
                    alertService.unregister(type: type, for: uuid)
                    expect(alertService.isOn(type: type, for: uuid)).to(beFalse())
                }
                it("must not return type if it contains in persistence") {
                    alertService.unregister(type: type, for: uuid)
                    expect(alertService.alert(for: uuid, of: type)).to(beNil())
                }
                it("must send notification AlertServiceAlertDidChange with userInfo") {
                    expect {
                        alertService.unregister(type: type, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
        }

        // MARK: - Temperature

        describe("Temperature") {
            context("when set lower") {
                it("must return lower") {
                    alertService.setLower(celsius: randomDouble, for: uuid)
                    expect(alertService.lowerCelsius(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if set upper temp is set must send notification AlertServiceAlertDidChange with type .temperature(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(celsius: randomDouble, for: uuid)
                    expect {
                        alertService.setLower(celsius: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(celsius: randomDouble, for: uuid)
                    expect(alertService.upperCelsius(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if lower temp is set must send notification AlertServiceAlertDidChange with type .temperature(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(celsius: randomDouble, for: uuid)
                    expect {
                        alertService.setUpper(celsius: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setTemperature(description: uuid, for: uuid)
                    expect(alertService.temperatureDescription(for: uuid)).to(equal(uuid))
                }
                // swiftlint:disable:next line_length
                it("if upper and lower temp is set, must send notification AlertServiceAlertDidChange with type .temperature(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(celsius: randomDouble, for: uuid)
                    alertService.alertPersistence.setLower(celsius: randomDouble, for: uuid)
                    expect {
                        alertService.setTemperature(description: uuid, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
        }

        // MARK: - Relative Humidity

        describe("Relative Humidity") {
            context("when set lower") {
                it("must return lower") {
                    alertService.setLower(humidity: Humidity(randomDouble), for: uuid)
                    expect(alertService.lowerHumidity(for: uuid)?.value.isEqual(to: randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if upper is set must send notification AlertServiceAlertDidChange with type .relativeHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(relativeHumidity: randomDouble, for: uuid)
                    expect {
                        alertService.setLower(relativeHumidity: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(relativeHumidity: randomDouble, for: uuid)
                    expect(alertService.upperRelativeHumidity(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if lower is set must send notification AlertServiceAlertDidChange with type .relativeHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(relativeHumidity: randomDouble, for: uuid)
                    expect {
                        alertService.setUpper(relativeHumidity: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setRelativeHumidity(description: uuid, for: uuid)
                    expect(alertService.relativeHumidityDescription(for: uuid)).to(equal(uuid))
                }
                // swiftlint:disable:next line_length
                it("if upper and lower relative humidity is set, must send notification AlertServiceAlertDidChange with type .relativeHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(relativeHumidity: randomDouble, for: uuid)
                    alertService.alertPersistence.setLower(relativeHumidity: randomDouble, for: uuid)
                    expect {
                        alertService.setRelativeHumidity(description: uuid, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
        }

        // MARK: - Absolute Humidity

        describe("Absolute Humidity") {
            context("when set lower") {
                it("must return lower") {
                    alertService.setLower(absoluteHumidity: randomDouble, for: uuid)
                    expect(alertService.lowerAbsoluteHumidity(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if upper is set must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(absoluteHumidity: randomDouble, for: uuid)
                    expect {
                        alertService.setLower(absoluteHumidity: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(absoluteHumidity: randomDouble, for: uuid)
                    expect(alertService.upperAbsoluteHumidity(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if lower is set must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(absoluteHumidity: randomDouble, for: uuid)
                    expect {
                        alertService.setUpper(absoluteHumidity: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setAbsoluteHumidity(description: uuid, for: uuid)
                    expect(alertService.absoluteHumidityDescription(for: uuid)).to(equal(uuid))
                }
                // swiftlint:disable:next line_length
                it("if upper and lower absolute humidity is set, must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(absoluteHumidity: randomDouble, for: uuid)
                    alertService.alertPersistence.setLower(absoluteHumidity: randomDouble, for: uuid)
                    expect {
                        alertService.setAbsoluteHumidity(description: uuid, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
        }

        // MARK: - Dew Point

        describe("Dew Point") {
            context("when set lower") {
                it("must return lower") {
                    alertService.setLowerDewPoint(celsius: randomDouble, for: uuid)
                    expect(alertService.lowerDewPointCelsius(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if upper is set must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpperDewPoint(celsius: randomDouble, for: uuid)
                    expect {
                        alertService.setLowerDewPoint(celsius: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpperDewPoint(celsius: randomDouble, for: uuid)
                    expect(alertService.upperDewPointCelsius(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if lower is set must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setLowerDewPoint(celsius: randomDouble, for: uuid)
                    expect {
                        alertService.setUpperDewPoint(celsius: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setDewPoint(description: uuid, for: uuid)
                    expect(alertService.dewPointDescription(for: uuid)).to(equal(uuid))
                }
                // swiftlint:disable:next line_length
                it("if upper and lower is set, must send notification AlertServiceAlertDidChange with type .dewPoint(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpperDewPoint(celsius: randomDouble, for: uuid)
                    alertService.alertPersistence.setLowerDewPoint(celsius: randomDouble, for: uuid)
                    expect {
                        alertService.setDewPoint(description: uuid, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
        }

        // MARK: - Pressure

        describe("Pressure") {
            context("when set lower") {
                it("must return lower") {
                    alertService.setLower(pressure: randomDouble, for: uuid)
                    expect(alertService.lowerPressure(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if upper is set must send notification AlertServiceAlertDidChange with type .pressure(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(pressure: randomDouble, for: uuid)
                    expect {
                        alertService.setLower(pressure: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(pressure: randomDouble, for: uuid)
                    expect(alertService.upperPressure(for: uuid)).to(equal(randomDouble))
                }
                // swiftlint:disable:next line_length
                it("if lower is set must send notification AlertServiceAlertDidChange with type .pressure(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(pressure: randomDouble, for: uuid)
                    expect {
                        alertService.setUpper(pressure: randomDouble, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setPressure(description: uuid, for: uuid)
                    expect(alertService.pressureDescription(for: uuid)).to(equal(uuid))
                }
                // swiftlint:disable:next line_length
                it("if upper and lower pressure is set, must send notification AlertServiceAlertDidChange with type .pressure(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(pressure: randomDouble, for: uuid)
                    alertService.alertPersistence.setUpper(pressure: randomDouble, for: uuid)
                    expect {
                        alertService.setPressure(description: uuid, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
        }

        // MARK: - Connection

        describe("Connection") {
            context("when set description") {
                it("must return description") {
                    alertService.setConnection(description: uuid, for: uuid)
                    expect(alertService.connectionDescription(for: uuid)).to(equal(uuid))
                }
                it("must send notification AlertServiceAlertDidChange with type .connection") {
                    alertService.setConnection(description: uuid, for: uuid)
                }
            }
        }

        // MARK: - Movement

        describe("Movement") {
            context("when set counter") {
                it("must retur counter") {
                    let randomInt: Int = .init(randomDouble)
                    alertService.setMovement(counter: randomInt, for: uuid)
                    expect(alertService.movementCounter(for: uuid)).to(equal(randomInt))
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setMovement(description: uuid, for: uuid)
                    expect(alertService.movementDescription(for: uuid)).to(equal(uuid))
                }
                it("must send notification AlertServiceAlertDidChange with type .movement(last: c)") {
                    let randomInt: Int = .init(randomDouble)
                    alertService.alertPersistence.setMovement(counter: randomInt, for: uuid)
                    expect {
                        alertService.setMovement(description: uuid, for: uuid)
                    }.toEventually(
                        postNotifications(self.equalName(.AlertServiceAlertDidChange, for: uuid)
                        ), timeout: self.notificationWaitTimeout
                    )
                }
            }
        }

        // MARK: - HeartBeat

        describe("HeartBeat process") {
            context("temperature trigger") {
                it("if less") {
                    alertService.register(type: .temperature(lower: randomDouble, upper: randomDouble + 10), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, celsius: randomDouble - 10)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.temperature))
                }
                it("if greather") {
                    alertService.register(type: .temperature(lower: randomDouble - 10, upper: randomDouble), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, celsius: randomDouble + 10)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.temperature))
                }
            }
            context("relativeHumidity trigger") {
                it("if less") {
                    alertService.register(
                        type: .relativeHumidity(
                            lower: randomPercentDouble,
                            upper: randomPercentDouble + 10
                        ),
                        for: uuid
                    )
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, humidity: randomPercentDouble - 10)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.relativeHumidity))
                }
                it("if greather") {
                    alertService.register(
                        type: .relativeHumidity(
                            lower: randomPercentDouble - 10,
                            upper: randomPercentDouble
                        ),
                        for: uuid
                    )
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, humidity: randomPercentDouble + 10)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.relativeHumidity))
                }
            }
            context("absoluteHumidity trigger") {
                it("if less") {
                    let lh = Humidity(c: randomDouble, rh: 1)
                    let uh = Humidity(c: randomDouble, rh: 1)
                    let h = Humidity(c: randomDouble, rh: 0)
                    alertService.register(type: .absoluteHumidity(lower: lh.ah, upper: uh.ah), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, humidity: h.ah, celsius: randomDouble)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.absoluteHumidity))
                }
                it("if greather") {
                    let lh = Humidity(c: randomDouble, rh: 0)
                    let uh = Humidity(c: randomDouble, rh: 0)
                    let h = Humidity(c: randomDouble, rh: 1)
                    alertService.register(type: .absoluteHumidity(lower: lh.ah, upper: uh.ah), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, humidity: h.rh, celsius: randomDouble)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.absoluteHumidity))
                }
            }
            context("dewPoint trigger") {
                it("if less") {
                    let h = Humidity(c: 30, rh: 0.8)
                    alertService.register(type: .dewPoint(lower: -33, upper: -32), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, humidity: h.rh, celsius: 30)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.dewPoint))
                }
                it("if greather") {
                    let h = Humidity(c: 30, rh: 0.8)
                    alertService.register(type: .dewPoint(lower: -36, upper: -35), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, humidity: h.rh, celsius: 30)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.dewPoint))
                }
            }
            context("pressure trigger") {
                it("if less") {
                    alertService.register(type: .pressure(lower: randomDouble, upper: randomDouble + 10), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, pressure: randomDouble - 10)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.pressure))
                }
                it("if greather") {
                    alertService.register(type: .pressure(lower: randomDouble - 10, upper: randomDouble), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let tag: RuuviTagProtocol = MockRuuviTag(uuid: uuid, pressure: randomDouble + 10)
                    alertService.process(heartbeat: tag)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.pressure))
                }
            }
        }

        // MARK: - WPSData

        describe("WPSData process") {
            context("temperature trigger") {
                it("if less") {
                    alertService.register(type: .temperature(lower: randomDouble, upper: randomDouble + 10), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: randomDouble - 10, humidity: nil, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.temperature))
                }
                it("if greather") {
                    alertService.register(type: .temperature(lower: randomDouble - 10, upper: randomDouble), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: randomDouble + 10, humidity: nil, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.temperature))
                }
            }
            context("relativeHumidity trigger") {
                it("if less") {
                    alertService.register(
                        type: .relativeHumidity(
                            lower: randomPercentDouble,
                            upper: randomPercentDouble + 10
                        ),
                        for: uuid
                    )
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: nil, humidity: randomPercentDouble - 10, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.relativeHumidity))
                }
                it("if greather") {
                    alertService.register(
                        type: .relativeHumidity(
                            lower: randomPercentDouble - 10,
                            upper: randomPercentDouble
                        ),
                        for: uuid
                    )
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: nil, humidity: randomPercentDouble + 10, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.relativeHumidity))
                }
            }
            context("absoluteHumidity trigger") {
                it("if less") {
                    let lh = Humidity(c: randomDouble, rh: 1)
                    let uh = Humidity(c: randomDouble, rh: 1)
                    let h = Humidity(c: randomDouble, rh: 0)
                    alertService.register(type: .absoluteHumidity(lower: lh.ah, upper: uh.ah), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: randomDouble, humidity: h.ah, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.absoluteHumidity))
                }
                it("if greather") {
                    let lh = Humidity(c: randomDouble, rh: 0)
                    let uh = Humidity(c: randomDouble, rh: 0)
                    let h = Humidity(c: randomDouble, rh: 1)
                    alertService.register(type: .absoluteHumidity(lower: lh.ah, upper: uh.ah), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: randomDouble, humidity: h.rh, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.absoluteHumidity))
                }
            }
            context("dewPoint trigger") {
                it("if less") {
                    let h = Humidity(c: 30, rh: 0.8)
                    alertService.register(type: .dewPoint(lower: -33, upper: -32), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: 30, humidity: h.rh, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.dewPoint))
                }
                it("if greather") {
                    let h = Humidity(c: 30, rh: 0.8)
                    alertService.register(type: .dewPoint(lower: -36, upper: -35), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: 30, humidity: h.rh, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.dewPoint))
                }
            }
            context("pressure trigger") {
                it("if less") {
                    alertService.register(type: .pressure(lower: randomDouble, upper: randomDouble + 10), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: nil, humidity: nil, pressure: randomDouble - 10)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.pressure))
                }
                it("if greather") {
                    alertService.register(type: .pressure(lower: randomDouble - 10, upper: randomDouble), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = .init(celsius: nil, humidity: nil, pressure: randomDouble + 10)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))

                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.high))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.pressure))
                }
            }
        }
    }

    func equalName(_ expectedName: Notification.Name, for uuid: String) -> Predicate<[Notification]> {
        Predicate.define("equal <\(stringify(expectedName))>") { actualExpression, msg in
            guard let actualValue = try actualExpression.evaluate()
            else {
                return PredicateResult(status: .fail, message: msg)
            }

            let actualNames = actualValue
                .filter { $0.name == expectedName }
                .filter { notification in
                    guard let userInfo = notification.userInfo
                    else {
                        return false
                    }
                    return userInfo[RuuviServiceAlertDidChangeKey.uuid] as? String == uuid
                }
                .compactMap(\.name)
            let matches = actualNames.contains(expectedName)
            return PredicateResult(bool: matches, message: msg)
        }
    }
}

// swiftlint:enable file_length
