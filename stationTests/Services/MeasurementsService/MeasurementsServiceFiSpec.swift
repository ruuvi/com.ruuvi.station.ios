import Humidity
import Nimble
import Quick
import XCTest

@testable import station

class MeasurementsServiceFiSpec: QuickSpec {
    override func spec() {
        let r = AppAssembly.shared.assembler.resolver
        var service: MeasurementsService! = r.resolve(MeasurementsService.self)
        var settings: RuuviLocalSettings! = r.resolve(RuuviLocalSettings.self)
        settings.temperatureUnit = .celsius
        beforeEach {
            settings.language = .finnish
            HumiditySettings.setLanguage(settings.language.humidityLanguage)
        }
        describe("Temperature") {
            context("with finnish locale") {
                it("belowZeroTemp string") {
                    let temp = Temperature(value: -10.2154, unit: .celsius)
                    expect(service.string(for: temp))
                        .to(equal("−10,22 °C"))
                }
                it("underZeroTemp string") {
                    let temp = Temperature(value: 10000.2134, unit: .celsius)
                    expect(service.string(for: temp))
                        .to(equal("10\(String.nbsp)000,21\(String.nbsp)°C"))
                }
                it("intTemp string") {
                    let temp = Temperature(value: 10.00, unit: .celsius)
                    expect(service.string(for: temp))
                        .to(equal("10,00\(String.nbsp)°C"))
                }
                it("decimalTemp string") {
                    let temp = Temperature(value: 0.10, unit: .celsius)
                    expect(service.string(for: temp))
                        .to(equal("0,10\(String.nbsp)°C"))
                }
                it("string without sign celsius") {
                    let temp = Temperature(value: 0.10, unit: .celsius)
                    expect(service.stringWithoutSign(for: temp))
                        .to(equal("0,10"))
                }
                it("string without sign kelvin") {
                    let temp = Temperature(value: 250.10, unit: .kelvin)
                    service.units = MeasurementsServiceSettigsUnit(temperatureUnit: .kelvin,
                                                                   humidityUnit: settings.humidityUnit,
                                                                   pressureUnit: settings.pressureUnit)
                    expect(service.stringWithoutSign(for: temp))
                        .to(equal("250,10"))
                }
                it("string without sign fahrenheit") {
                    let temp = Temperature(value: 73.10, unit: .fahrenheit)
                    service.units = MeasurementsServiceSettigsUnit(temperatureUnit: .fahrenheit,
                                                                   humidityUnit: settings.humidityUnit,
                                                                   pressureUnit: settings.pressureUnit)
                    settings.temperatureUnit = .fahrenheit
                    expect(service.stringWithoutSign(for: temp))
                        .to(equal("73,10"))
                }
            }
        }
        describe("Relative Humidity") {
            let temp = Temperature(24.0)
            context("with finnish locale") {
                beforeEach {
                    settings.humidityUnit = .percent
                    service.updateUnits()
                }
                it("without offset") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = nil
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("50,00\(String.nbsp)%"))
                }
                it("with offset 0.2") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("70,00\(String.nbsp)%"))
                }
                it("with offset -0.13") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = -0.13
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("77,00\(String.nbsp)%"))
                }
                it("with offset greather than 100 %") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("100,00\(String.nbsp)%"))
                }
                it("with offset less than 0 %") {
                    let humidity = Humidity(relative: 0.1, temperature: temp)
                    let offset: Double? = -0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("0,00\(String.nbsp)%"))
                }
                it("double without offset") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = nil
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(0.5))
                }
                it("double with offset 0.2") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(0.7))
                }
                it("double with offset -0.13") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = -0.13
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(0.77))
                }
                it("double with offset greather than 100 %") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(1.0))
                }
                it("double with offset less than 0 %") {
                    let humidity = Humidity(relative: 0.1, temperature: temp)
                    let offset: Double? = -0.2
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(0.0))
                }
            }
        }
        describe("Absolute Humidity") {
            let temp = Temperature(24.0)
            context("with finnish locale") {
                beforeEach {
                    settings.humidityUnit = .gm3

                    service.updateUnits()
                }
                it("without offset") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = nil
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("10,89\(String.nbsp)g/m³"))
                }
                it("with offset 0.2") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("15,24\(String.nbsp)g/m³"))
                }
                it("with offset -0.13") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = -0.13
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("16,76\(String.nbsp)g/m³"))
                }
                it("with offset greather than 100 %") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("21,77\(String.nbsp)g/m³"))
                }
                it("with offset less than 0 %") {
                    let humidity = Humidity(relative: 0.1, temperature: temp)
                    let offset: Double? = -0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("0,00\(String.nbsp)g/m³"))
                }
                it("double without offset") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = nil
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(10.89))
                }
                it("double with offset 0.2") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(15.24))
                }
                it("double with offset -0.13") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = -0.13
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(16.76))
                }
                it("double with offset greather than 100 %") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(21.77))
                }
                it("double with offset less than 0 %") {
                    let humidity = Humidity(relative: 0.1, temperature: temp)
                    let offset: Double? = -0.2
                    expect(service.double(for: humidity, withOffset: offset, temperature: temp, isDecimal: true))
                        .to(equal(0.0))
                }
            }
        }
        describe("dew point") {
            let temp = Temperature(24.0)
            context("with finnish locale") {
                beforeEach {
                    settings.humidityUnit = .dew
                    settings.temperatureUnit = .celsius
                    service.updateUnits()
                }
                it("without offset") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = nil
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("12,95\(String.nbsp)°C"))
                }
                it("with offset 0.2") {
                    let humidity = Humidity(relative: 0.5, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("18,20\(String.nbsp)°C"))
                }
                it("with offset -0.13") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = -0.13
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("19,73\(String.nbsp)°C"))
                }
                it("with offset greather than 100 %") {
                    let humidity = Humidity(relative: 0.9, temperature: temp)
                    let offset: Double? = 0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("24,01\(String.nbsp)°C"))
                }
                it("with offset less than 0 %") {
                    let humidity = Humidity(relative: 0.1, temperature: temp)
                    let offset: Double? = -0.2
                    expect(service.string(for: humidity, withOffset: offset, temperature: temp))
                        .to(equal("−240,73 °C"))
                }
            }
        }
        describe("Pressure") {
            context("with finnish locale") {
                it("hectopascals") {
                    let pressure = Pressure(value: 1024.6543, unit: .hectopascals)
                    settings.pressureUnit = .hectopascals
                    service.updateUnits()
                    expect(service.string(for: pressure))
                        .to(equal("1\(String.nbsp)024,65 hPa"))
                }
                it("inchesOfMercury") {
                    let pressure = Pressure(value: 24.6543, unit: .inchesOfMercury)
                    settings.pressureUnit = .inchesOfMercury
                    service.updateUnits()
                    expect(service.string(for: pressure))
                        .to(equal("24,65 inHg"))
                }
                it("intTemp string") {
                    let pressure = Pressure(value: 765.201, unit: .millimetersOfMercury)
                    settings.pressureUnit = .millimetersOfMercury
                    service.updateUnits()
                    expect(service.string(for: pressure))
                        .to(equal("765,20 mm Hg"))
                }
            }
        }
        describe("Voltage") {
            context("with finnish locale") {
                it("volts") {
                    let volts = Voltage(value: 2.35123, unit: .volts)
                    expect(service.string(for: volts))
                        .to(equal("2,35 V"))
                }
            }
        }
    }
}
