Pod::Spec.new do |s|
  s.name             = 'RuuviCore'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Core'
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
    ss.source_files = 'Sources/RuuviCore/**/*.{h,m,swift}', 'Sources/RuuviCore/*.{h,m,swift}'
    ss.dependency 'FutureX'
  end

  s.subspec 'Image' do |ss|
    ss.source_files = 'Sources/RuuviCoreImage/**/*.{h,m,swift}', 'Sources/RuuviCoreImage/*.{h,m,swift}'
    ss.dependency 'RuuviCore/Contract'
    ss.dependency 'FutureX'
  end

  s.subspec 'Location' do |ss|
    ss.source_files = 'Sources/RuuviCoreLocation/**/*.{h,m,swift}', 'Sources/RuuviCoreLocation/*.{h,m,swift}'
    ss.dependency 'RuuviCore/Contract'
  end

  s.subspec 'Diff' do |ss|
    ss.source_files = 'Sources/RuuviCoreDiff/**/*.{h,m,swift}', 'Sources/RuuviCoreDiff/*.{h,m,swift}'
  end

  s.subspec 'PN' do |ss|
    ss.source_files = 'Sources/RuuviCorePN/**/*.{h,m,swift}', 'Sources/RuuviCorePN/*.{h,m,swift}'
    ss.dependency 'RuuviCore/Contract'
  end

  s.subspec 'Permission' do |ss|
    ss.source_files = 'Sources/RuuviCorePermission/**/*.{h,m,swift}', 'Sources/RuuviCorePermission/*.{h,m,swift}'
    ss.dependency 'RuuviCore/Contract'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end
