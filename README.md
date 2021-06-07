# Ruuvi Station

[![Swift Version][swift-image]][swift-url]
[![Build Status](https://travis-ci.org/ruuvi/com.ruuvi.station.ios.svg?branch=master)](https://travis-ci.org/ruuvi/com.ruuvi.station.ios)
[![License][license-image]][license-url]
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

Ruuvi Station is an open-source iOS app [available](https://itunes.apple.com/us/app/ruuvi-station/id1384475885) on the AppStore. You can observe environment data read from RuuviTag beacon, such as temperature, humidity, air pressure (and more) right on your iOS device. Ruuvi Station is a companion app for open-source IoT BLE devices made by [Ruuvi](https://ruuvi.com).

<p align="center">
  <img src="/docs/screenshot0.jpeg?raw=true" alt="Ruuvi Station for iOS" height="400"/>
  <img src="/docs/screenshot1.jpeg?raw=true" alt="Ruuvi Station for iOS" height="400"/>
  <img src="/docs/screenshot2.jpeg?raw=true" alt="Ruuvi Station for iOS" height="400"/>
  <img src="/docs/screenshot3.jpeg?raw=true" alt="Ruuvi Station for iOS" height="400"/>
</p>

<p align="center">
  <a href="https://itunes.apple.com/us/app/ruuvi-station/id1384475885"><img src="docs/Download_on_the_App_Store_Badge.svg?raw=true&sanitize=true" alt="Ruuvi Station for iOS"></a>
</p>

## RuuviTag

<p align="center">
  <a href="https://shop.ruuvi.com"><img src="/docs/ruuvitag-enclosure-open.jpg?raw=true" alt="RuuviTag" height="200"/></a>
  <a href="https://shop.ruuvi.com"><img src="/docs/ruuvitag1.jpg?raw=true" alt="RuuviTag" height="200"/></a>
  <a href="https://shop.ruuvi.com"><img src="/docs/ruuvitag2.jpg?raw=true" alt="RuuviTag" height="200"/></a>
</p>

[RuuviTag](https://ruuvi.com) is an advanced open-source sensor beacon platform designed to fulfill the needs of business customers, developers, makers, students, and can even be used in your home and as part of your personal endeavours. The device is set up to work as soon as you take it out of its box and is ready to be deployed to where you need it. Whether you need a beehive monitor in your backyard, or an industrial mesh network asset tracking system, [RuuviTag](https://ruuvi.com) gets you covered. 

## Features

- [x] Temperature (°C, °F, K)
- [x] Humidity (relative in %, absolute in g/m³)
- [x] Dew Point (°C, °F, K)
- [x] Air Pressure (hPa)
- [x] Acceleration (g)
- [x] Charts
- [x] Background logging
- [x] Localization (English, Finnish, Russian, Swedish)
- [x] Virtual Sensors 

## Requirements

- iOS 10.0+
- Xcode 11.3

## How to use

1. Clone the repo with the recursive parameter  ```git clone --recursive https://github.com/ruuvi/com.ruuvi.station.ios.git```
2. ```cd``` into repo and run: ```pod install --repo-update```
3. Open ```station.xcworkspace```
4. Configure Signing  
Optional: 
5. Obtain [OpenWeatherMap](https://openweathermap.org) API Key and put it into ```/station/Classes/Networking/Assembly/Networking.plist```
6. Setup your [Firebase](https://firebase.google.com) project and replace ```station/Resources/Plists/GoogleService-Info.plist```

Build and Run on your device!

## Get in touch

Join our [Slack](https://slack.ruuvi.com) community. Feel free to ask ``@rinat`` about iOS code.  

Join our [Telegram](https://t.me/ruuvicom) community. Feel free to ask ``@rinatru`` about iOS code. 

## How to buy

You can order RuuviTag sensors [online](https://shop.ruuvi.com). Find more info about the devices on [Ruuvi.com](https://ruuvi.com). 

## Contribute

We would love you for the contribution to **Ruuvi Station**, check the ``LICENSE`` file for more info.

## Branches

AppStore build source code is available at `master` branch. 

Public Beta build source code is available at `beta` branch. 

Latest TestFlight build source code is available at `testflight` branch.

Internal Alpha build source code is available at `alpha` branch. 

Development source code is available at `dev` branch.  

<!-- Please don't remove this: Grab your social icons from https://github.com/carlsednaoui/gitsocial -->

[![Twitter][twitter-image]][twitter]
[![Facebook][facebook-image]][facebook]
[![Github][github-image]][github]

[github-image]:http://i.imgur.com/0o48UoR.png
[github]:https://github.com/ruuvi
[facebook-image]:http://i.imgur.com/P3YfQoD.png
[facebook]:https://www.facebook.com/ruuvi.cc/
[twitter-image]:http://i.imgur.com/tXSoThF.png
[twitter]:https://twitter.com/ruuvicom
[swift-image]:https://img.shields.io/badge/swift-5.0-orange.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-BSD-blue.svg
[license-url]: LICENSE
