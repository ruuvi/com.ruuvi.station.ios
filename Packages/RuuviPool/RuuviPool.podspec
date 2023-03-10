Pod::Spec.new do |s|
  s.name             = 'RuuviPool'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Pool'
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
    ss.source_files = 'Sources/RuuviPool/**/*.{h,m,swift}', 'Sources/RuuviPool/*.{h,m,swift}'
    ss.dependency 'FutureX'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviPersistence'
    ss.dependency 'RuuviLocal'
  end

  s.subspec 'Coordinator' do |ss|
    ss.source_files = 'Sources/RuuviPoolCoordinator/**/*.{h,m,swift}', 'Sources/RuuviPoolCoordinator/*.{h,m,swift}'
    ss.dependency 'RuuviPool/Contract'
    ss.dependency 'RuuviPersistence'
    ss.dependency 'RuuviPersistence/Realm'
    ss.dependency 'RuuviPersistence/SQLite'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviLocal'
    ss.dependency 'FutureX'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end

