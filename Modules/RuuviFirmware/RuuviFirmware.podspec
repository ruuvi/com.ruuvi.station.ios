Pod::Spec.new do |s|
  s.name             = 'RuuviDiscover'
  s.version          = '0.0.2'
  s.summary          = 'Ruuvi Discover'
  s.homepage         = 'https://ruuvi.com'
  s.author           = { 'Rinat Enikeev' => 'rinat@ruuvi.com' }
  s.license          = { :type => 'BSD 3-Clause', :file => '../../LICENSE' }
  s.platform         = :ios, '10.0'
  s.source           = { git: 'https://github.com/ruuvi/com.ruuvi.station.ios' }
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
  s.ios.deployment_target = '10.0'
  s.swift_version    = '5.0'

  s.default_subspecs = 'RuuviDiscover'

  s.subspec 'RuuviDiscover' do |ss|
    ss.source_files = 'Sources/RuuviDiscover/**/*.{h,m,swift}', 'Sources/RuuviDiscover/*.{h,m,swift}'
    ss.resource_bundles = {
        'RuuviDiscover' => ['Sources/**/Resources/**/*']
    }

    ss.dependency 'BTKit'
    ss.dependency 'RuuviContext'
    ss.dependency 'RuuviReactor'
    ss.dependency 'RuuviLocal'
    ss.dependency 'RuuviService'
    ss.dependency 'RuuviCore'
    ss.dependency 'RuuviLocalization'
    ss.dependency 'RuuviPresenters'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end


