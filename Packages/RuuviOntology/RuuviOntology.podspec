Pod::Spec.new do |s|
  s.name             = 'RuuviOntology'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Ontology'
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
    ss.source_files = 'Sources/RuuviOntology/**/*.{h,m,swift}', 'Sources/RuuviOntology/*.{h,m,swift}'
    ss.dependency 'Humidity'
  end

  s.subspec 'Mappers' do |ss|
    ss.source_files = 'Sources/RuuviOntologyMappers/**/*.{h,m,swift}', 'Sources/RuuviOntologyMappers/*.{h,m,swift}'
    ss.dependency 'RuuviOntology/Contract'
    ss.dependency 'BTKit'
    ss.dependency 'Humidity'
  end

  s.subspec 'SQLite' do |ss|
    ss.source_files = 'Sources/RuuviOntologySQLite/**/*.{h,m,swift}', 'Sources/RuuviOntologySQLite/*.{h,m,swift}'
    ss.dependency 'RuuviOntology/Contract'
    ss.dependency 'GRDB.swift'
    ss.dependency 'Humidity'
  end

  s.subspec 'Realm' do |ss|
    ss.source_files = 'Sources/RuuviOntologyRealm/**/*.{h,m,swift}', 'Sources/RuuviOntologyRealm/*.{h,m,swift}'
    ss.dependency 'RuuviOntology/Contract'
    ss.dependency 'Realm'
    ss.dependency 'RealmSwift', '~> 10.33.0'
    ss.dependency 'Humidity'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end

