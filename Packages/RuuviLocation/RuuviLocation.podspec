Pod::Spec.new do |s|
  s.name             = 'RuuviLocation'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Location'
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
    ss.source_files = 'Sources/RuuviLocation/**/*.{h,m,swift}', 'Sources/RuuviLocation/*.{h,m,swift}'
    ss.dependency 'FutureX'
    ss.dependency 'RuuviOntology'
  end

  s.subspec 'Service' do |ss|
    ss.source_files = 'Sources/RuuviLocationService/**/*.{h,m,swift}', 'Sources/RuuviLocationService/*.{h,m,swift}'
    ss.dependency 'RuuviLocation/Contract'
    ss.dependency 'RuuviOntology'
  end
  
  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end


