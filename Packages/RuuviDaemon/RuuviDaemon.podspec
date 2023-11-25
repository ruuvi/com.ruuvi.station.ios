Pod::Spec.new do |s|
  s.name             = 'RuuviDaemon'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Daemon'
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
    ss.source_files = 'Sources/RuuviDaemon/**/*.{h,m,swift}', 'Sources/RuuviDaemon/*.{h,m,swift}'
  end

  s.subspec 'Worker' do |ss|
    ss.source_files = 'Sources/RuuviDaemonWorker/**/*.{h,m,swift}', 'Sources/RuuviDaemonWorker/*.{h,m,swift}'
  end

  s.subspec 'CloudSync' do |ss|
    ss.source_files = 'Sources/RuuviDaemonCloudSync/**/*.{h,m,swift}', 'Sources/RuuviDaemonCloudSync/*.{h,m,swift}'
    ss.dependency 'RuuviDaemon/Contract'
    ss.dependency 'RuuviDaemon/Worker'
    ss.dependency 'RuuviService'
    ss.dependency 'RuuviLocal'
  end

  s.subspec 'Background' do |ss|
    ss.source_files = 'Sources/RuuviDaemonBackground/**/*.{h,m,swift}', 'Sources/RuuviDaemonBackground/*.{h,m,swift}'
    ss.dependency 'RuuviDaemon/Contract'
    ss.dependency 'RuuviDaemon/Operation'
  end

  s.subspec 'Operation' do |ss|
    ss.source_files = 'Sources/RuuviDaemonOperation/**/*.{h,m,swift}', 'Sources/RuuviDaemonOperation/*.{h,m,swift}'
    ss.dependency 'RuuviDaemon/Contract'
    ss.dependency 'RuuviStorage'
    ss.dependency 'RuuviLocal'
    ss.dependency 'RuuviPool'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviNotifier'
    ss.dependency 'FutureX'
  end

  s.subspec 'RuuviTag' do |ss|
    ss.source_files = 'Sources/RuuviDaemonRuuviTag/**/*.{h,m,swift}', 'Sources/RuuviDaemonRuuviTag/*.{h,m,swift}'
    ss.dependency 'RuuviDaemon/Contract'
    ss.dependency 'BTKit'
    ss.dependency 'RuuviLocal'
    ss.dependency 'RuuviPool'
    ss.dependency 'RuuviReactor'
    ss.dependency 'RuuviStorage'
    ss.dependency 'RuuviPersistence'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviService'
    ss.dependency 'RuuviNotification'
    ss.dependency 'RuuviNotifier'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end
