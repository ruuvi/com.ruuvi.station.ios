Pod::Spec.new do |s|
  s.name             = 'RuuviNetwork'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Network'
  s.homepage         = 'https://ruuvi.com'
  s.author           = { 'Rinat Enikeev' => 'rinat@ruuvi.com' }
  s.license          = { :type => 'BSD 3-Clause', :file => '../../LICENSE' }
  s.platform         = :ios, '10.0'
  s.source           = { git: 'https://github.com/ruuvi/com.ruuvi.station.ios' }
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
  s.ios.deployment_target = '10.0'
  s.swift_version    = '5.0'

  s.default_subspecs = 'Contract'

  s.subspec 'Contract' do |ss|
    ss.source_files = 'Sources/RuuviNetwork/**/*.{h,m,swift}', 'Sources/RuuviNetwork/*.{h,m,swift}'
    ss.dependency 'FutureX'
  end

  s.subspec 'Pure' do |ss|
    ss.source_files = 'Sources/RuuviNetworkPure/**/*.{h,m,swift}', 'Sources/RuuviNetworkPure/*.{h,m,swift}'
    ss.dependency 'RuuviNetwork/Contract'
    ss.dependency 'FutureX'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end
