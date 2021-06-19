Pod::Spec.new do |s|
  s.name             = 'RuuviReactor'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Reactor'
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
    ss.source_files = 'Sources/RuuviReactor/**/*.{h,m,swift}', 'Sources/RuuviReactor/*.{h,m,swift}'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviPersistence'
  end

  s.subspec 'Impl' do |ss|
    ss.source_files = 'Sources/RuuviReactorImpl/**/*.{h,m,swift}', 'Sources/RuuviReactorImpl/*.{h,m,swift}'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviContext'
    ss.dependency 'RealmSwift'
    ss.dependency 'GRDB.swift'
    ss.dependency 'FutureX'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end

