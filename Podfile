platform :ios, '10.0'
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
  pod 'RuuviCloud', :path => 'Packages/RuuviCloud/RuuviCloud.podspec', :testspecs => ['Tests']
  pod 'RuuviCloud/Pure', :path => 'Packages/RuuviCloud/RuuviCloud.podspec'
  pod 'RuuviStorage', :path => 'Packages/RuuviStorage/RuuviStorage.podspec', :testspecs => ['Tests']
  pod 'RuuviStorage/Coordinator', :path => 'Packages/RuuviStorage/RuuviStorage.podspec'
  pod 'RxSwift'
  pod 'Swinject'
  pod 'SwinjectPropertyLoader', :git => 'https://github.com/rinat-enikeev/SwinjectPropertyLoader'
  pod 'SwiftGen', '~> 6.0'
  pod 'KeychainAccess'
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
