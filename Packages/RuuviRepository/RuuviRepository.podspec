Pod::Spec.new do |s|
  s.name             = 'RuuviRepository'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Repository'
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
    ss.source_files = 'Sources/RuuviRepository/**/*.{h,m,swift}', 'Sources/RuuviRepository/*.{h,m,swift}'
    ss.dependency 'FutureX'
    ss.dependency 'RuuviOntology'
  end

  s.subspec 'Coordinator' do |ss|
    ss.source_files = 'Sources/RuuviRepositoryCoordinator/**/*.{h,m,swift}', 'Sources/RuuviRepositoryCoordinator/*.{h,m,swift}'
    ss.dependency 'RuuviRepository/Contract'
    ss.dependency 'RuuviPool'
    ss.dependency 'RuuviStorage'
    ss.dependency 'RuuviOntology'
    ss.dependency 'FutureX'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end


