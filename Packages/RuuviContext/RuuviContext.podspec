Pod::Spec.new do |s|
  s.name             = 'RuuviContext'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Context'
  s.homepage         = 'https://ruuvi.com'
  s.author           = { 'Rinat Enikeev' => 'rinat@ruuvi.com' }
  s.license          = { :type => 'BSD 3-Clause', :file => '../../LICENSE' }
  s.platform         = :ios, '10.0'
  s.source           = { git: 'https://github.com/ruuvi/com.ruuvi.station.ios' }
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
  s.ios.deployment_target = '10.0'
  s.swift_version    = '5.0'

  s.default_subspecs = 'SQLite'

  s.subspec 'Contract' do |ss|
    ss.source_files = 'Sources/RuuviContext/**/*.{h,m,swift}', 'Sources/RuuviContext/*.{h,m,swift}'
  end

  s.subspec 'Realm' do |ss|
    ss.source_files = 'Sources/RuuviContextRealm/**/*.{h,m,swift}', 'Sources/RuuviContextRealm/*.{h,m,swift}'
    ss.dependency 'RuuviContext/Contract'
    ss.dependency 'Realm'
    ss.dependency 'RealmSwift'
  end

  s.subspec 'SQLite' do |ss|
    ss.source_files = 'Sources/RuuviContextSQLite/**/*.{h,m,swift}', 'Sources/RuuviContextSQLite/*.{h,m,swift}'
    ss.dependency 'RuuviContext/Contract'
    ss.dependency 'RuuviOntology/SQLite'
    ss.dependency 'GRDB.swift'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end

