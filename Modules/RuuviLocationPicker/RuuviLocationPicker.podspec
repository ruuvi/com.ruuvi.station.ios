Pod::Spec.new do |s|
  s.name             = 'RuuviLocationPicker'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi LocationPicker'
  s.homepage         = 'https://ruuvi.com'
  s.author           = { 'Rinat Enikeev' => 'rinat@ruuvi.com' }
  s.license          = { :type => 'BSD 3-Clause', :file => '../../LICENSE' }
  s.platform         = :ios, '10.0'
  s.source           = { git: 'https://github.com/ruuvi/com.ruuvi.station.ios' }
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
  s.ios.deployment_target = '10.0'
  s.swift_version    = '5.0'

  s.default_subspecs = 'RuuviLocationPicker'

  s.subspec 'RuuviLocationPicker' do |ss|
    ss.source_files = 'Sources/RuuviLocationPicker/**/*.{h,m,swift}', 'Sources/RuuviLocationPicker/*.{h,m,swift}'
    ss.resource_bundles = {
        'RuuviLocationPicker' => ['Sources/**/Resources/**/*']
    }

    ss.dependency 'RuuviCore'
    ss.dependency 'RuuviLocation'
    ss.dependency 'RuuviPresenters'
    ss.dependency 'RuuviLocalization'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end



