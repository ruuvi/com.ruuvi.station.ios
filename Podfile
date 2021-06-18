platform :ios, '10.0'
project 'station.xcodeproj'
use_frameworks!
inhibit_all_warnings!

install! 'cocoapods', :disable_input_output_paths => true

def shared_pods
  pod 'BTKit'
  pod 'Charts', :git => 'https://github.com/rinat-enikeev/Charts.git', :tag => 'v3.6.1'
  pod 'Firebase'
  pod 'Firebase/Messaging'
  pod 'Firebase/Analytics'
  pod 'Firebase/Crashlytics'
  pod 'Firebase/RemoteConfig'
  pod 'Firebase/InAppMessaging'
  pod 'FutureX'
  pod 'GestureInstructions'
  pod 'GRDB.swift'
  pod 'Humidity', :git => 'https://github.com/rinat-enikeev/Humidity.git'
  pod 'LightRoute', :git => 'https://github.com/rinat-enikeev/LightRoute.git'
  pod 'Localize-Swift'
  pod 'Nantes'
  pod 'RangeSeekSlider', :git => 'https://github.com/rinat-enikeev/RangeSeekSlider'
  pod 'Realm'
  pod 'RealmSwift'
  pod 'RuuviOntology', :path => 'Packages/RuuviOntology/RuuviOntology.podspec'
  pod 'RuuviContext', :path => 'Packages/RuuviContext/RuuviContext.podspec'
  pod 'RuuviCore', :path => 'Packages/RuuviCore/RuuviCore.podspec', :testspecs => ['Tests']
  pod 'RuuviCore/Image', :path => 'Packages/RuuviCore/RuuviCore.podspec'
  pod 'RuuviCloud', :path => 'Packages/RuuviCloud/RuuviCloud.podspec', :testspecs => ['Tests']
  pod 'RuuviCloud/Pure', :path => 'Packages/RuuviCloud/RuuviCloud.podspec'
  pod 'RuuviDaemon', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec', :testspecs => ['Tests']
  pod 'RuuviDaemon/CloudSync', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec'
  pod 'RuuviLocal/UserDefaults', :path => 'Packages/RuuviLocal/RuuviLocal.podspec'
  pod 'RuuviPersistence', :path => 'Packages/RuuviPersistence/RuuviPersistence.podspec', :testspecs => ['Tests']
  pod 'RuuviReactor', :path => 'Packages/RuuviReactor/RuuviReactor.podspec', :testspecs => ['Tests']
  pod 'RuuviReactor/Impl', :path => 'Packages/RuuviReactor/RuuviReactor.podspec'
  pod 'RuuviStorage', :path => 'Packages/RuuviStorage/RuuviStorage.podspec', :testspecs => ['Tests']
  pod 'RuuviStorage/Coordinator', :path => 'Packages/RuuviStorage/RuuviStorage.podspec'
  pod 'RuuviService', :path => 'Packages/RuuviService/RuuviService.podspec', :testspecs => ['Tests']
  pod 'RuuviService/CloudSync', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/Ownership', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/SensorProperties', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/SensorRecords', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/AppSettings', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/OffsetCalibration', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/Alert', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviPool', :path => 'Packages/RuuviPool/RuuviPool.podspec', :testspecs => ['Tests']
  pod 'RuuviPool/Coordinator', :path => 'Packages/RuuviPool/RuuviPool.podspec'
  pod 'RuuviRepository', :path => 'Packages/RuuviRepository/RuuviRepository.podspec', :testspecs => ['Tests']
  pod 'RuuviRepository/Coordinator', :path => 'Packages/RuuviRepository/RuuviRepository.podspec'
  pod 'RuuviUser', :path => 'Packages/RuuviUser/RuuviUser.podspec', :testspecs => ['Tests']
  pod 'RuuviUser/Coordinator', :path => 'Packages/RuuviUser/RuuviUser.podspec'
  pod 'RxSwift'
  pod 'Swinject'
  pod 'SwinjectPropertyLoader', :git => 'https://github.com/rinat-enikeev/SwinjectPropertyLoader'
  pod 'SwiftGen', '~> 6.0'
  pod 'KeychainAccess'
  pod 'iOSDFULibrary'
end

target 'station' do
  shared_pods
end

target 'station_dev' do
  shared_pods
  pod 'FLEX', :configurations => ['Debug']
end

target 'stationTests' do
  shared_pods
  pod 'Nimble'
  pod 'Quick'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 9.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
      end
    end
  end
end
