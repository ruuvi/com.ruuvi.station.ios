Pod::Spec.new do |s|
  s.name             = 'RuuviNotification'
  s.version          = '0.0.2'
  s.summary          = 'Ruuvi Notification'
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
    ss.source_files = 'Sources/RuuviNotification/**/*.{h,m,swift}', 'Sources/RuuviNotification/*.{h,m,swift}'
  end

  s.subspec 'Local' do |ss|
    ss.source_files = 'Sources/RuuviNotificationLocal/**/*.{h,m,swift}', 'Sources/RuuviNotificationLocal/*.{h,m,swift}'
    ss.dependency 'RuuviNotification/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviStorage'
    ss.dependency 'RuuviLocal'
    ss.dependency 'RuuviService'
    ss.dependency 'RuuviVirtual'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end
