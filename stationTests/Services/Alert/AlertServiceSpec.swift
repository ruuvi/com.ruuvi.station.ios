//
//  AlertServiceSpec.swift
//  stationTests
//
//  Created by Viik.ufa on 13.03.2020.
//  Copyright © 2020 Ruuvi Innovations Oy. All rights reserved.
//

import XCTest
import Quick
import Nimble
import Humidity
@testable import station

class AlertServiceSpec: QuickSpec {
    override func spec() {
        let alertService = AlertServiceImpl()
        alertService.alertPersistence = AlertPersistenceUserDefaults()

        let localNotificationManager = MockLocalNotificationsManager()
        alertService.localNotificationsManager = localNotificationManager

        alertService.calibrationService = MockCalibrationService()
        var uuid: String = UUID().uuidString
        var randomDouble: Double = Double.random(in: -100...100)
        var randomPercentDouble: Double = Double.random(in: 10...90)
        let type: AlertType = .connection
        beforeEach {
            randomPercentDouble = Double.random(in: 10...90)
            randomDouble = Double.random(in: -100...100)
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
                //TODO: - expect AlertServiceAlertDidChange notification
                it("must send notification AlertServiceAlertDidChange with userInfo") {
                    alertService.register(type: type, for: uuid)
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
                //TODO: - expect AlertServiceAlertDidChange notification
                it("must send notification AlertServiceAlertDidChange with userInfo") {
                    alertService.unregister(type: type, for: uuid)
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
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper temp is setted must send notification AlertServiceAlertDidChange with type .temperature(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(celsius: randomDouble, for: uuid)
                    alertService.setLower(celsius: randomDouble, for: uuid)
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(celsius: randomDouble, for: uuid)
                    expect(alertService.upperCelsius(for: uuid)).to(equal(randomDouble))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if lower temp is setted must send notification AlertServiceAlertDidChange with type .temperature(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(celsius: randomDouble, for: uuid)
                    alertService.setUpper(celsius: randomDouble, for: uuid)
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setTemperature(description: uuid, for: uuid)
                    expect(alertService.temperatureDescription(for: uuid)).to(equal(uuid))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper and lower temp is setted, must send notification AlertServiceAlertDidChange with type .temperature(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(celsius: randomDouble, for: uuid)
                    alertService.alertPersistence.setLower(celsius: randomDouble, for: uuid)
                    alertService.setTemperature(description: uuid, for: uuid)
                }
            }
        }
        // MARK: - Relative Humidity
        describe("Relative Humidity") {
            context("when set lower") {
                it("must return lower") {
                    alertService.setLower(relativeHumidity: randomDouble, for: uuid)
                    expect(alertService.lowerRelativeHumidity(for: uuid)).to(equal(randomDouble))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper is setted must send notification AlertServiceAlertDidChange with type .relativeHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(relativeHumidity: randomDouble, for: uuid)
                    alertService.setLower(relativeHumidity: randomDouble, for: uuid)
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(relativeHumidity: randomDouble, for: uuid)
                    expect(alertService.upperRelativeHumidity(for: uuid)).to(equal(randomDouble))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if lower is setted must send notification AlertServiceAlertDidChange with type .relativeHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(relativeHumidity: randomDouble, for: uuid)
                    alertService.setUpper(relativeHumidity: randomDouble, for: uuid)
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setRelativeHumidity(description: uuid, for: uuid)
                    expect(alertService.relativeHumidityDescription(for: uuid)).to(equal(uuid))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper and lower relative humidity is setted, must send notification AlertServiceAlertDidChange with type .relativeHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(celsius: randomDouble, for: uuid)
                    alertService.alertPersistence.setLower(celsius: randomDouble, for: uuid)
                    alertService.setRelativeHumidity(description: uuid, for: uuid)
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
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper is setted must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(absoluteHumidity: randomDouble, for: uuid)
                    alertService.setLower(absoluteHumidity: randomDouble, for: uuid)
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(absoluteHumidity: randomDouble, for: uuid)
                    expect(alertService.upperAbsoluteHumidity(for: uuid)).to(equal(randomDouble))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if lower is setted must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(absoluteHumidity: randomDouble, for: uuid)
                    alertService.setUpper(absoluteHumidity: randomDouble, for: uuid)
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setAbsoluteHumidity(description: uuid, for: uuid)
                    expect(alertService.absoluteHumidityDescription(for: uuid)).to(equal(uuid))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper and lower absolute humidity is setted, must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(absoluteHumidity: randomDouble, for: uuid)
                    alertService.alertPersistence.setLower(absoluteHumidity: randomDouble, for: uuid)
                    alertService.setAbsoluteHumidity(description: uuid, for: uuid)
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
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper is setted must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpperDewPoint(celsius: randomDouble, for: uuid)
                    alertService.setLowerDewPoint(celsius: randomDouble, for: uuid)
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpperDewPoint(celsius: randomDouble, for: uuid)
                    expect(alertService.upperDewPointCelsius(for: uuid)).to(equal(randomDouble))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if lower is setted must send notification AlertServiceAlertDidChange with type .absoluteHumidity(lower: l, upper: u)") {
                    alertService.alertPersistence.setLowerDewPoint(celsius: randomDouble, for: uuid)
                    alertService.setUpperDewPoint(celsius: randomDouble, for: uuid)
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setDewPoint(description: uuid, for: uuid)
                    expect(alertService.dewPointDescription(for: uuid)).to(equal(uuid))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper and lower is setted, must send notification AlertServiceAlertDidChange with type .dewPoint(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpperDewPoint(celsius: randomDouble, for: uuid)
                    alertService.alertPersistence.setLowerDewPoint(celsius: randomDouble, for: uuid)
                    alertService.setDewPoint(description: uuid, for: uuid)
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
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper is setted must send notification AlertServiceAlertDidChange with type .pressure(lower: l, upper: u)") {
                    alertService.alertPersistence.setUpper(pressure: randomDouble, for: uuid)
                    alertService.setLower(pressure: randomDouble, for: uuid)
                }
            }
            context("when set upper") {
                it("must return upper") {
                    alertService.setUpper(pressure: randomDouble, for: uuid)
                    expect(alertService.upperPressure(for: uuid)).to(equal(randomDouble))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if lower is setted must send notification AlertServiceAlertDidChange with type .pressure(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(pressure: randomDouble, for: uuid)
                    alertService.setUpper(pressure: randomDouble, for: uuid)
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setPressure(description: uuid, for: uuid)
                    expect(alertService.pressureDescription(for: uuid)).to(equal(uuid))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("if upper and lower pressure is setted, must send notification AlertServiceAlertDidChange with type .pressure(lower: l, upper: u)") {
                    alertService.alertPersistence.setLower(pressure: randomDouble, for: uuid)
                    alertService.alertPersistence.setUpper(pressure: randomDouble, for: uuid)
                    alertService.setPressure(description: uuid, for: uuid)
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
                //TODO: - expect AlertServiceAlertDidChange notification
                it("must send notification AlertServiceAlertDidChange with type .connection") {
                    alertService.setConnection(description: uuid, for: uuid)
                }
            }
        }
        // MARK: - Movement
        describe("Movement") {
            context("when set counter") {
                it("must retur counter") {
                    let randomInt: Int = Int(randomDouble)
                    alertService.setMovement(counter: randomInt, for: uuid)
                    expect(alertService.movementCounter(for: uuid)).to(equal(randomInt))
                }
            }
            context("when set description") {
                it("must return description") {
                    alertService.setMovement(description: uuid, for: uuid)
                    expect(alertService.movementDescription(for: uuid)).to(equal(uuid))
                }
                //TODO: - expect AlertServiceAlertDidChange notification
                it("must send notification AlertServiceAlertDidChange with type .movement(last: c)") {
                    alertService.setMovement(description: uuid, for: uuid)
                }
            }
        }
        // MARK: - HeartBit
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
                    alertService.register(type: .relativeHumidity(lower: randomPercentDouble, upper: randomPercentDouble + 10), for: uuid)
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
                    alertService.register(type: .relativeHumidity(lower: randomPercentDouble - 10, upper: randomPercentDouble), for: uuid)
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
        // MARK: - HeartBit
        describe("WPSData process") {
            context("temperature trigger") {
                it("if less") {
                    alertService.register(type: .temperature(lower: randomDouble, upper: randomDouble + 10), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = WPSData(celsius: randomDouble - 10, humidity: nil, pressure: nil)
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

                    let vTag: WPSData = WPSData(celsius: randomDouble + 10, humidity: nil, pressure: nil)
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
                    alertService.register(type: .relativeHumidity(lower: randomPercentDouble, upper: randomPercentDouble + 10), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = WPSData(celsius: nil, humidity: randomPercentDouble - 10, pressure: nil)
                    alertService.process(data: vTag, for: uuid)
                    expect(fakeDelegate.uuid).toEventually(equal(uuid))
                    expect(fakeDelegate.service).toEventuallyNot(beNil())
                    expect(localNotificationManager.uuid).toEventually(equal(uuid))
                    expect(localNotificationManager.reason).toEventually(equal(LowHighNotificationReason.low))
                    expect(localNotificationManager.type).toEventually(equal(LowHighNotificationType.relativeHumidity))
                }
                it("if greather") {
                    alertService.register(type: .relativeHumidity(lower: randomPercentDouble - 10, upper: randomPercentDouble), for: uuid)
                    let fakeDelegate = MockAlertServiceObserver()
                    alertService.subscribe(fakeDelegate, to: uuid)

                    let vTag: WPSData = WPSData(celsius: nil, humidity: randomPercentDouble + 10, pressure: nil)
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

                    let vTag: WPSData = WPSData(celsius: randomDouble, humidity: h.ah, pressure: nil)
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

                    let vTag: WPSData = WPSData(celsius: randomDouble, humidity: h.rh, pressure: nil)
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

                    let vTag: WPSData = WPSData(celsius: 30, humidity: h.rh, pressure: nil)
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

                    let vTag: WPSData = WPSData(celsius: 30, humidity: h.rh, pressure: nil)
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

                    let vTag: WPSData = WPSData(celsius: nil, humidity: nil, pressure: randomDouble - 10)
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

                    let vTag: WPSData = WPSData(celsius: nil, humidity: nil, pressure: randomDouble + 10)
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
}
