platform :ios, '13.0'
project 'station.xcodeproj'
use_frameworks!
inhibit_all_warnings!

install! 'cocoapods', :disable_input_output_paths => true

def shared_pods
  pod 'BTKit'
  pod 'Firebase'
  pod 'Firebase/Messaging'
  pod 'Firebase/Analytics'
  pod 'Firebase/Crashlytics'
  pod 'Firebase/RemoteConfig'
  pod 'Firebase/InAppMessaging'
  pod 'FutureX'
  pod 'GestureInstructions'
  pod 'GRDB.swift', '~> 4.14.0'
  pod 'Humidity', :git => 'https://github.com/rinat-enikeev/Humidity.git'
  pod 'LightRoute', :git => 'https://github.com/rinat-enikeev/LightRoute.git'
  pod 'Localize-Swift'
  pod 'Nantes'
  pod 'RangeSeekSlider', :git => 'https://github.com/rinat-enikeev/RangeSeekSlider'
  pod 'Realm'
  pod 'RealmSwift'
  # modules
  pod 'RuuviDiscover', :path => 'Modules/RuuviDiscover/RuuviDiscover.podspec', :testspecs => ['Tests']
  pod 'RuuviOnboard', :path => 'Modules/RuuviOnboard/RuuviOnboard.podspec', :testspecs => ['Tests']
  # packages
  pod 'RuuviAnalytics', :path => 'Packages/RuuviAnalytics/RuuviAnalytics.podspec', :testspecs => ['Tests']
  pod 'RuuviAnalytics/Impl', :path => 'Packages/RuuviAnalytics/RuuviAnalytics.podspec'
  pod 'RuuviOntology', :path => 'Packages/RuuviOntology/RuuviOntology.podspec'
  pod 'RuuviContext', :path => 'Packages/RuuviContext/RuuviContext.podspec'
  pod 'RuuviCore', :path => 'Packages/RuuviCore/RuuviCore.podspec', :testspecs => ['Tests']
  pod 'RuuviCore/Image', :path => 'Packages/RuuviCore/RuuviCore.podspec'
  pod 'RuuviCore/Location', :path => 'Packages/RuuviCore/RuuviCore.podspec'
  pod 'RuuviCore/Diff', :path => 'Packages/RuuviCore/RuuviCore.podspec'
  pod 'RuuviCore/PN', :path => 'Packages/RuuviCore/RuuviCore.podspec'
  pod 'RuuviCore/Permission', :path => 'Packages/RuuviCore/RuuviCore.podspec'
  pod 'RuuviCloud', :path => 'Packages/RuuviCloud/RuuviCloud.podspec', :testspecs => ['Tests']
  pod 'RuuviCloud/Pure', :path => 'Packages/RuuviCloud/RuuviCloud.podspec'
  pod 'RuuviDFU', :path => 'Packages/RuuviDFU/RuuviDFU.podspec', :testspecs => ['Tests']
  pod 'RuuviDFU/Impl', :path => 'Packages/RuuviDFU/RuuviDFU.podspec'
  pod 'RuuviDaemon', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec', :testspecs => ['Tests']
  pod 'RuuviDaemon/CloudSync', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec'
  pod 'RuuviDaemon/Operation', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec'
  pod 'RuuviDaemon/RuuviTag', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec'
  pod 'RuuviDaemon/VirtualTag', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec'
  pod 'RuuviDaemon/Background', :path => 'Packages/RuuviDaemon/RuuviDaemon.podspec'
  pod 'RuuviLocal/UserDefaults', :path => 'Packages/RuuviLocal/RuuviLocal.podspec'
  pod 'RuuviLocation', :path => 'Packages/RuuviLocation/RuuviLocation.podspec', :testspecs => ['Tests']
  pod 'RuuviLocation/Service', :path => 'Packages/RuuviLocation/RuuviLocation.podspec'
  pod 'RuuviNotification', :path => 'Packages/RuuviNotification/RuuviNotification.podspec', :testspecs => ['Tests']
  pod 'RuuviNotification/Local', :path => 'Packages/RuuviNotification/RuuviNotification.podspec'
  pod 'RuuviNotifier', :path => 'Packages/RuuviNotifier/RuuviNotifier.podspec', :testspecs => ['Tests']
  pod 'RuuviNotifier/Impl', :path => 'Packages/RuuviNotifier/RuuviNotifier.podspec'
  pod 'RuuviMigration', :path => 'Packages/RuuviMigration/RuuviMigration.podspec', :testspecs => ['Tests']
  pod 'RuuviMigration/Impl', :path => 'Packages/RuuviMigration/RuuviMigration.podspec'
  pod 'RuuviPersistence', :path => 'Packages/RuuviPersistence/RuuviPersistence.podspec', :testspecs => ['Tests']
  pod 'RuuviReactor', :path => 'Packages/RuuviReactor/RuuviReactor.podspec', :testspecs => ['Tests']
  pod 'RuuviReactor/Impl', :path => 'Packages/RuuviReactor/RuuviReactor.podspec'
  pod 'RuuviStorage', :path => 'Packages/RuuviStorage/RuuviStorage.podspec', :testspecs => ['Tests']
  pod 'RuuviStorage/Coordinator', :path => 'Packages/RuuviStorage/RuuviStorage.podspec'
  pod 'RuuviService', :path => 'Packages/RuuviService/RuuviService.podspec', :testspecs => ['Tests']
  pod 'RuuviService/Factory', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/CloudSync', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/Ownership', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/SensorProperties', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/SensorRecords', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/AppSettings', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/OffsetCalibration', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/Alert', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/Measurement', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/Export', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviService/GATT', :path => 'Packages/RuuviService/RuuviService.podspec'
  pod 'RuuviPool', :path => 'Packages/RuuviPool/RuuviPool.podspec', :testspecs => ['Tests']
  pod 'RuuviPool/Coordinator', :path => 'Packages/RuuviPool/RuuviPool.podspec'
  pod 'RuuviRepository', :path => 'Packages/RuuviRepository/RuuviRepository.podspec', :testspecs => ['Tests']
  pod 'RuuviRepository/Coordinator', :path => 'Packages/RuuviRepository/RuuviRepository.podspec'
  pod 'RuuviUser', :path => 'Packages/RuuviUser/RuuviUser.podspec', :testspecs => ['Tests']
  pod 'RuuviUser/Coordinator', :path => 'Packages/RuuviUser/RuuviUser.podspec'
  pod 'RuuviVirtual', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec', :testspecs => ['Tests']
  pod 'RuuviVirtual/Storage', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec'
  pod 'RuuviVirtual/Reactor', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec'
  pod 'RuuviVirtual/Persistence', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec'
  pod 'RuuviVirtual/Model', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec'
  pod 'RuuviVirtual/Repository', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec'
  pod 'RuuviVirtual/Service', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec'
  pod 'RuuviVirtual/OWM', :path => 'Packages/RuuviVirtual/RuuviVirtual.podspec'
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
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 13.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
end
