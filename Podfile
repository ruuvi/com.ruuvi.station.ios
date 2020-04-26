platform :ios, '10.0'
use_frameworks!
inhibit_all_warnings!

install! 'cocoapods', :disable_input_output_paths => true

def shared_pods
  pod 'BTKit'
  pod 'Charts'
  pod 'Firebase/Messaging'
  pod 'Firebase/Analytics'
  pod 'FutureX'
  pod 'GestureInstructions'
  pod 'Humidity'
  pod 'LightRoute', :git => 'https://github.com/rinat-enikeev/LightRoute.git'
  pod 'Localize-Swift'
  pod 'Nantes'
  pod 'RangeSeekSlider', :git => 'https://github.com/rinat-enikeev/RangeSeekSlider'
  pod 'RealmSwift'
  pod 'Swinject'
  pod 'SwinjectPropertyLoader', :git => 'https://github.com/rinat-enikeev/SwinjectPropertyLoader'
  pod 'KeychainAccess'
  pod 'FLEX', :configurations => ['Debug']
end

target 'station' do
  shared_pods
end

target 'station_dev' do
  shared_pods
end

target 'stationTests' do
  shared_pods
  pod 'Nimble'
  pod 'Quick'
end
