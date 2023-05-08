Pod::Spec.new do |s|
  s.name             = 'RuuviPersistence'
  s.version          = '0.0.2'
  s.summary          = 'Ruuvi Persistence'
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
    ss.source_files = 'Sources/RuuviPersistence/**/*.{h,m,swift}', 'Sources/RuuviPersistence/*.{h,m,swift}'
    ss.dependency 'FutureX'
    ss.dependency 'RuuviOntology'
  end

  s.subspec 'Realm' do |ss|
    ss.source_files = 'Sources/RuuviPersistenceRealm/**/*.{h,m,swift}', 'Sources/RuuviPersistenceRealm/*.{h,m,swift}'
    ss.dependency 'RuuviPersistence/Contract'
    ss.dependency 'RuuviContext/Realm'
    ss.dependency 'RuuviOntology/Realm'
    ss.dependency 'RuuviOntology'
    ss.dependency 'Realm'
    ss.dependency 'RealmSwift', '~> 10.33.0'
    ss.dependency 'FutureX'
  end

  s.subspec 'SQLite' do |ss|
    ss.source_files = 'Sources/RuuviPersistenceSQLite/**/*.{h,m,swift}', 'Sources/RuuviPersistenceSQLite/*.{h,m,swift}'
    ss.dependency 'RuuviPersistence/Contract'
    ss.dependency 'RuuviContext/SQLite'
    ss.dependency 'RuuviOntology/SQLite'
    ss.dependency 'RuuviOntology'
    ss.dependency 'GRDB.swift'
    ss.dependency 'FutureX'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end
