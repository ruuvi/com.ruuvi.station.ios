fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## iOS
### ios test
```
fastlane ios test
```

### ios reg
```
fastlane ios reg
```
Register devices
### ios upload_to_firebase
```
fastlane ios upload_to_firebase
```

  Upload to firebase AppDistribution with options

  -group - testers group [alpha|beta]
  -notes - release notes for testers
  -scheme - [station|station_dev]

  fastlane ios upload_to_firebase group:alpha notes:'New feature' scheme:station_dev
  

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
