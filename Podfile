platform :ios, '10.0'
use_frameworks!
inhibit_all_warnings!

install! 'cocoapods', :disable_input_output_paths => true

def shared_pods
  pod 'BTKit', '~> 0.1.13'
  pod 'Charts'
  pod 'Firebase'
  pod 'Firebase/Messaging'
  pod 'Firebase/Analytics'
  pod 'Firebase/Crashlytics'
  pod 'Firebase/InAppMessaging'
  pod 'FutureX'
  pod 'GestureInstructions'
  pod 'GRDB.swift', '4.14.0'
  pod 'Humidity'
  pod 'LightRoute', :git => 'https://github.com/rinat-enikeev/LightRoute.git'
  pod 'Localize-Swift'
  pod 'Nantes'
  pod 'RangeSeekSlider', :git => 'https://github.com/rinat-enikeev/RangeSeekSlider'
  pod 'RealmSwift'
  pod 'RxSwift'
  pod 'Swinject'
  pod 'SwinjectPropertyLoader', :git => 'https://github.com/rinat-enikeev/SwinjectPropertyLoader'
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
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
    end
  end
end
