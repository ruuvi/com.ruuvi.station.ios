Pod::Spec.new do |s|
  s.name             = 'RuuviOnboard'
  s.version          = '0.0.4'
  s.summary          = 'Ruuvi Onboard'
  s.homepage         = 'https://ruuvi.com'
  s.author           = { 'Rinat Enikeev' => 'rinat@ruuvi.com' }
  s.license          = { :type => 'BSD 3-Clause', :file => '../../LICENSE' }
  s.platform         = :ios, '10.0'
  s.source           = { git: 'https://github.com/ruuvi/com.ruuvi.station.ios' }
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
  s.ios.deployment_target = '10.0'
  s.swift_version    = '5.0'

  s.default_subspecs = 'RuuviOnboard'

  s.subspec 'RuuviOnboard' do |ss|
    ss.source_files = 'Sources/RuuviOnboard/**/*.{h,m,swift}', 'Sources/RuuviOnboard/*.{h,m,swift}'
    ss.resource_bundles = {
        'RuuviOnboard' => ['Sources/**/Resources/**/*']
    }
    ss.dependency 'RuuviBundleUtils'
    ss.dependency 'RuuviUser'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end


