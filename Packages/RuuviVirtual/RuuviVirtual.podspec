Pod::Spec.new do |s|
  s.name             = 'RuuviVirtual'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Virtual'
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
    ss.source_files = 'Sources/RuuviVirtual/**/*.{h,m,swift}', 'Sources/RuuviVirtual/*.{h,m,swift}'
    ss.dependency 'FutureX'
    ss.dependency 'RuuviOntology'
  end

  s.subspec 'Model' do |ss|
    ss.source_files = 'Sources/RuuviVirtualModel/**/*.{h,m,swift}', 'Sources/RuuviVirtualModel/*.{h,m,swift}'
    ss.dependency 'RuuviVirtual/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'FutureX'
    ss.dependency 'RealmSwift'
  end

  s.subspec 'Persistence' do |ss|
    ss.source_files = 'Sources/RuuviVirtualPersistence/**/*.{h,m,swift}', 'Sources/RuuviVirtualPersistence/*.{h,m,swift}'
    ss.dependency 'RuuviVirtual/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviLocal'
    ss.dependency 'RuuviContext/Realm'
    ss.dependency 'RealmSwift'
  end

  s.subspec 'Storage' do |ss|
    ss.source_files = 'Sources/RuuviVirtualStorage/**/*.{h,m,swift}', 'Sources/RuuviVirtualStorage/*.{h,m,swift}'
    ss.dependency 'RuuviVirtual/Contract'
    ss.dependency 'RuuviOntology'
  end

  s.subspec 'Repository' do |ss|
    ss.source_files = 'Sources/RuuviVirtualRepository/**/*.{h,m,swift}', 'Sources/RuuviVirtualRepository/*.{h,m,swift}'
    ss.dependency 'RuuviVirtual/Contract'
    ss.dependency 'RuuviOntology'
  end

  s.subspec 'Reactor' do |ss|
    ss.source_files = 'Sources/RuuviVirtualReactor/**/*.{h,m,swift}', 'Sources/RuuviVirtualReactor/*.{h,m,swift}'
    ss.dependency 'RuuviVirtual/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviContext/Realm'
  end

  s.subspec 'Service' do |ss|
    ss.source_files = 'Sources/RuuviVirtualService/**/*.{h,m,swift}', 'Sources/RuuviVirtualService/*.{h,m,swift}'
    ss.dependency 'RuuviVirtual/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviVirtual/OWM'
    ss.dependency 'RuuviLocation/Service'
    ss.dependency 'RuuviCore/Location'
  end

  s.subspec 'OWM' do |ss|
    ss.source_files = 'Sources/RuuviVirtualOWM/**/*.{h,m,swift}', 'Sources/RuuviVirtualOWM/*.{h,m,swift}'
    ss.dependency 'RuuviVirtual/Contract'
    ss.dependency 'FutureX'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end

